package GBV::SRUSelect;
use v5.20;
use utf8;    # UTF-8 im Quelltext

use parent 'Plack::Component';
use Plack::Request;
use Plack::Response;
use Catmandu 'exporter';
use Catmandu::Importer::SRU;
use Try::Tiny;
use PICA::Data ':all';
use JSON;
use Encode::Unicode qw(encode);

use Plack::Util::Accessor qw(databases default_database);

sub json {
    return [ JSON->new->utf8->allow_blessed->encode(shift) ];
}

sub path {
    my ( $path, $subfields ) = @_;
    try {
        $path = pica_path($path);
    }
    catch {
        die [ 400, "Ungültiger PICA Path Ausdruck '$path'" ];
    };
    if ( defined $subfields ) {
        die [ 400, "PICA Path Ausdruck '$path' darf keine Unterfelder haben" ]
          if defined $path->subfields && !$subfields;
        die [ 400, "PICA Path Ausdruck '$path' fehlen Unterfelder" ]
          if !defined $path->subfields && $subfields;
    }
    return $path;
}

# TODO: move to PICA::Data as part of pica_split
sub levels {
    my ( $record, $level ) = @_;
    return $record unless $level;

    my @records;

    my $level0 = pica_title($record)->{record};

    for my $holding ( @{ pica_holdings($record) } ) {
        if ( $level eq '01' ) {
            unshift @{ $holding->{record} }, @$level0;
            push @records, $holding;
        }
        else {    # '012'
            my $level1 = pica_fields( $holding, '1.../*' );
            for my $item ( @{ pica_items($holding) } ) {

                unshift @{ $item->{record} }, @$level0, @$level1;
                push @records, $item;
            }
        }
    }

    return @records;
}

sub call {
    my ( $self, $env ) = @_;
    return $self->select( Plack::Request->new($env)->query_parameters );
}

sub select {
    my ( $self, $params ) = @_;

    my $debug = $params->{debug};

    my $res =
      Plack::Response->new( 200, [ 'Content-Type' => 'application/json' ] );

    try {
        my $cql = $params->{query};
        my $db  = $params->{db};

        my $format = $params->{format} || 'pp';
        die "Format not supported"
          if $format !~ /^(json|pp|norm|tsv|csv|ods|table)$/;

        my @map;

        if ( my $levels = $params->{levels} ) {
            die [ 400, "Levels darf nur 0, 01 oder 012 sein!\n" ]
              if $levels !~ /^0|01|012$/;
            push @map, sub { return levels( $_[0], $levels ) };
        }

        if ( my $reduce = $params->{reduce} ) {
            $reduce =~ s/\s+//mg;
            $reduce = [ map { path( $_, 0 ) } split /[|,]+/, $reduce ];
            push @map, sub { return pica_fields( $_[0], @$reduce ); }
        }

        my $records = $self->query( db => $db, cql => $cql );

        $records = $records->map($_) for @map;
        $records = $records->to_array;

        if ( $format eq 'json' ) {
            $res->body( json($records) );
        }
        elsif ( $format eq 'pp' || $format eq 'norm' ) {
            $format = $format eq 'pp' ? 'plain' : 'plus';
            my $body   = "";
            my $writer = pica_writer( $format, \$body );
            $writer->write($_) for @$records;
            $writer->end;
            $res->header( 'Content-Type' => 'text/plain; encoding=UTF-8' );

            # TODO: decode UTF-8? use iterator instead?
            $res->body( [$body] );
        }
        elsif ( $format =~ /^(tsv|csv|ods|table)$/ ) {
            my @lines = grep { $_ } map { s/^\s+|\s+$//mgr; } split "\n",
              $params->{select} // '';
            my @fields = grep { $_ } map {
                $_ =~ s/\s+\$/\$/;
                $_ = ~/^(([\p{L}0-9_-]+):)?\s*(.+)/;
                { name => $2 || $3, value => "" . path( $3, 1 ) };
            } @lines;

            die [ 400,
                "Bitte eine Auswahl pro Zeile der Form '(Name:) Feld \$codes'" ]
              unless @fields && @fields == @lines;

            my $separator = $params->{separator};
            my $extract =
              defined $separator
              ? sub { join $separator, pica_values(@_) }
              : sub { pica_value(@_) };

            my @rows;
            for my $rec (@$records) {
                push @rows,
                  { map { $_->{name} => $extract->( $rec, $_->{value} ) }
                      @fields };
            }

            if ( $format eq 'table' ) {
                $res->body( json( { fields => \@fields, rows => \@rows } ) );
            }
            else {
                my $body = '';
                my @opts = (
                    file   => \$body,
                    fields => [ map { $_->{name} } @fields ]
                );
                if ( $format eq 'tsv' ) {
                    $res->header(
                        'Content-Type' => 'text/tab-separated-values' );
                    exporter( TSV => @opts )->add_many( \@rows );
                }
                else {    # TODO: support ODS with OpenOffice::OODoc
                    $res->header( 'Content-Type' => 'text/csv' );
                    exporter( CSV => @opts )->add_many( \@rows );
                }
                $res->body( [$body] );
            }
        }
    }
    catch {
        my ( $code, $msg ) = ref $_ ? @$_ : ( 500, $_ );
        $msg =~ s/ at .+ line .+//sm unless $debug;
        $res->code($code);
        $res->body( json( { message => $msg, status => $code } ) );
    };

    return $res->finalize;
}

sub query {
    my ( $self, %params ) = @_;

    my $db = $self->databases->{ $params{db} || $self->{default_database} }
      or die [ 400, "Unbekannte oder fehlende Datenbank" ];

    my $cql = $params{cql}
      or die [ 400, "Fehlende CQL-Abfrage" ];

    my $limit = $params{limit};
    $limit = 10 if !( $limit > 0 ) || $limit > 100;

    # TODO: optionally add xpn, user, password...
    # TODO: add X-Total-Count header

    return Catmandu::Importer::SRU->new(
        base         => $db->{srubase},
        version      => '1.1',
        recordSchema => 'picaxml',
        parser       => 'picaxml',
        query        => $cql,
        total        => $limit,
    );
}

1;

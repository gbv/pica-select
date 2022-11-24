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
use List::Util      qw(any all);

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
          if !$subfields && defined $path->subfields;
        die [ 400, "PICA Path Ausdruck '$path' fehlen Unterfelder" ]
          if $subfields && !defined $path->subfields;
    }
    return $path;
}

sub filter {
    my ($filter) = @_;

    my @parts;
    for ( split '&&', $filter ) {

        # TODO: allow multiple filter expressions (and/or). Pass to pica-rs?
        $_ =~ /^(.+)\s*(==|!=)\s*'([^']*)'$/
          or die [ 400, "Ungültiger Filter-Ausdruck!\n" ];

        my ( $path, $operator, $value ) = ( path( $1, 1 ), $2, $3 );

        push @parts, sub {
            my @values = pica_values( $_[0], $path );
            return $operator eq '=='
              ? any { $_ eq $value } @values
              : any { $_ ne $value } @values;
        };
    }

    return sub {
        my $record = shift;
        return all { $_->($record) } @parts;
    }
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

        my $level;
        if ( my $l = $params->{level} ) {
            die [ 400, "Level darf nur 0, 1 oder 2 sein!\n" ]
              if $l !~ /^[012]$/;
            $level = sub { return pica_split( $_[0], $l ) };
        }

        my $reduce;
        if ( my $r = $params->{reduce} =~ s/\s+//mgr ) {
            $r      = [ map { path( $_, 0 ) } split /[|,]+/, $r ];
            $reduce = sub {
                return pica_fields( $_[0], @$r );
            };
        }

        my $filter = $params->{filter} =~ s/\s+|\s+//gr;
        $filter = filter($filter) if $filter;

        my $records = $self->query( db => $db, cql => $cql );

        $records = $records->map($level)     if $level;
        $records = $records->select($filter) if $filter;
        $records = $records->map($reduce)    if $reduce;
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
            $body =~ s/\n+$/\n/s;
            $res->body( [$body] );
        }
        elsif ( $format =~ /^(tsv|csv|ods|table)$/ ) {
            my @lines = grep { $_ } map { s/^\s+|\s+$//mgr; } split "\n",
              $params->{select} // '';
            ## no critic
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

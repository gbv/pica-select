package GBV::SRUSelect;
use v5.20;
use utf8;    # UTF-8 im Quelltext

use parent 'Plack::Component';
use Plack::Request;
use Plack::Response;
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
        if ( defined $path->subfields ) {
            die [
                400, "PICA Patch Ausdruck '$path' darf keine Unterfelder haben"
              ]
              if !$subfields;
        }
        else {
            die [ 400, "PICA Patch Ausdruck '$path' fehlen Unterfelder" ]
              if $subfields;
        }
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
            for my $rec (@$records) {
                $writer->write($rec);
            }
            $writer->end;
            $res->header( 'Content-Type' => 'text/plain; encoding=UTF-8' );

            # TODO: decode UTF-8? use iterator instead?
            $res->body( [$body] );
        }
        elsif ( $format =~ /^(tsv|csv|ods|table)$/ ) {
            my $select = $params->{select};
            $select =~ s/^\s+|\s+$//mg;
            die [ 400, "Bitte Unterfelder angeben" ] unless $select;

            # TODO allow optional field names e.g. ppn:003@$
            my @path = map { path( $_, 1 ) } split /,/, $select;

            my $separator = $params->{separator};
            my @rows =
              map {
                my $rec = $_;

                # TODO: respect separator
                {
                    map { $_ => pica_value( $rec, $_ ) } @path
                }
              } @$records;

            if ( $format eq 'table' ) {

                # TODO?: include 'fields' (JSON Table Schema)
                # or use https://www.w3.org/TR/csv2json/
                # { tables => [ { row => \@rows } ] }
                $res->body( json( { rows => \@rows } ) );
            }
            else {
                # TODO: properly support CSV and ODS
                $res->header( 'Content-Type' => 'text/plain' );

                # TSV
                $records = [ map { join( "\t", @$_ ) . "\n" } @rows ];

                $res->body($records);
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

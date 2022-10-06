package GBV::SRUSelect;
use v5.20;

use parent 'Plack::Component';
use Plack::Request;
use Plack::Response;
use Catmandu::Importer::SRU;
use Try::Tiny;
use PICA::Data qw(pica_writer pica_path pica_value pica_fields);
use JSON;
use Encode::Unicode qw(encode);

use Plack::Util::Accessor qw(databases default_database);

sub json {
    return [ JSON->new->utf8->allow_blessed->encode(shift) ];
}

use utf8;    # UTF-8 im Quelltext

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

sub call {
    my ( $self, $env ) = @_;

    my $req    = Plack::Request->new($env);
    my $params = $req->query_parameters;
    my $debug  = $params->{debug};

    my $res =
      Plack::Response->new( 200, [ 'Content-Type' => 'application/json' ] );

    try {
        my $cql = $params->{query};
        my $db  = $params->{db};

        my $format = $params->{format} || 'pp';
        die "Format not supported" if $format !~ /^(json|pp|norm|tsv|csv|ods)$/;

        my $select = $params->{select};
        $select =~ s/^\s+|\s+$//mg;

        my $records = $self->query( db => $db, cql => $cql );

        # TODO: split records if requested

        if ( my $reduce = $params->{reduce} ) {
            $reduce =~ s/\s+//mg;

            $reduce  = [ map { path( $_, 0 ) } split /[|,]+/, $reduce ];
            $records = $records->map(
                sub {
                    return pica_fields( $_[0], @$reduce );
                }
            );
        }

        $records = $records->to_array;

        # TODO: Reduktion auf einzelne Felder mit select
        # TODO: Record separator

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
        elsif ( $format eq 'tsv' ) {
            die [ 400, "Bitte Unterfelder angeben" ] unless $select;
            my @path = map { path( $_, 1 ) } split /,/, $select;

            $res->header( 'Content-Type' => 'text/plain' );
            my @rows;
            for my $record (@$records) {
                my @row = map { pica_value( $record, $_ ) } @path;
                push @rows, join( "\t", @row ) . "\n";
            }

            $res->body( \@rows );
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

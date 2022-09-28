package GBV::SRUSelect;
use v5.20;

use parent 'Plack::Component';
use Plack::Request;
use Catmandu::Importer::SRU;
use Try::Tiny;
use PICA::Data qw(pica_writer pica_path);
use JSON;
use Encode::Unicode qw(encode);

use Plack::Util::Accessor qw(databases default_database);

use Plack::Response;

sub json {
    return [ JSON->new->utf8->encode(shift) ];
}

sub call {
    my ( $self, $env ) = @_;

    my $req   = Plack::Request->new($env);
    my $query = $req->query_parameters;

    my $response =
      Plack::Response->new( 200, [ 'Content-Type' => 'application/json' ] );

    # return configuration
    if ( !$query->keys ) {
        $response->body( json( {%$self} ) );
        return $response->finalize;
    }

    my $cql    = $query->{cql};
    my $db     = $query->{db};
    my $format = $query->{format} || 'pp';    # csv, tsv, pp, norm
    my $select = $query->{select};

    my $status = 500;

    try {
        die "Format not supported" if $format !~ /^(json|pp|norm|tsv)$/;
        if ( $format eq 'pp' ) {
        }

        # returns an iterator of PICA records
        my $records = $self->query( $db, $cql );

        my $res = $records->map(
            sub {
                bless $_[0], 'PICA::Data';
            }
        )->to_array;

        if ( $format eq 'json' ) {
            $response->body( json($res) );
        }
        elsif ( $format eq 'pp' || $format eq 'norm' ) {
            $format = $format eq 'pp' ? 'plain' : 'plus';
            my $body   = "";
            my $writer = pica_writer( $format, \$body );
            $writer->write($_) for @$res;
            $response->header( 'Content-Type' => 'text/plain; encoding=UTF-8' );

            # TODO: decode UTF-8?
            $response->body( [$body] );
        }
        elsif ( $format eq 'tsv' ) {
            die "Bitte Unterfelder angeben" unless $select;
            $select =~ s/^\s+|\s+$//mg;
            my @path = map { pica_path($_) } split /,/, $select;
            for (@path) {
                die "PICA Path Ausdruck '$_' hat keine Unterfelder!"
                  unless defined $_->subfields;
            }

            $response->header( 'Content-Type' => 'text/plain' );
            my @rows;
            for my $record (@$res) {
                my @row = map { $record->value($_) } @path;
                push @rows, join( "\t", @row ) . "\n";
            }

            $response->body( \@rows );
        }

        # TODO: to_json
    }
    catch {
        my ( $code, $msg ) = ref $_ ? @$_ : ( 500, $_ );
        say STDERR $msg;
        $msg =~ s/ at .+ line .+//sm;    # TODO: keep location in debug mode
        $response->code($code);
        $response->body( json( { message => $msg, status => $code } ) );
    };

    return $response->finalize;
}

sub query {
    my ( $self, $db, $cql ) = @_;

    my $limit = 10;

    # TODO: optionally add xpn, user, password...

    $db = $self->databases->{ $db || $self->default_database }
      or die [ 404, "Unbekannte oder fehlende Datenbank" ];

    die [ 400, "Missing CQL query" ] unless $cql;

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

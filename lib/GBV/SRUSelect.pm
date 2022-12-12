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
use Encode     qw(decode);
use List::Util qw(any all);
use GBV::PICASelector;
use Plack::Util::Accessor qw(databases default_database);

sub json {
    return [ to_json( shift, { utf8 => 1, convert_blessed => 1, @_ } ) ];
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

sub tabular {
    my ( $recs, $select, $separator ) = @_;

    my @cols = try {
        my @lines = grep { $_ !~ qr{^\s*(\#.*)?$} } split "\n", $select // '';
        ## no critic
        map {
            $_ =~ s/^\s+|\s+$//g;
            $_ =~ s/\s+\$/\$/;
            $_ = ~/^(([^: ]+):)?\s*(.+)/;
            { name => $2 || $3, value => GBV::PICASelector->new($3) };
        } @lines;
    };

    die [ 400, "Bitte eine Auswahl pro Zeile der Form '(Name:) Feld \$codes'" ]
      unless @cols;

    my @rows;
    for my $rec (@$recs) {
        my %row;
        for my $f (@cols) {
            my $value =
              defined $separator
              ? join $separator, $f->{value}->select_all($rec)
              : $f->{value}->select_first($rec);
            $row{ $f->{name} } = $value // "";
        }
        push @rows, \%row;
    }

    return {
        fields => \@cols,
        rows   => \@rows
    };
}

sub call {
    my ( $self, $env ) = @_;
    return $self->request( Plack::Request->new($env)->query_parameters );
}

sub request {
    my ( $self, $param ) = @_;

    my $debug = $param->{debug};
    $param->{$_} = decode( 'UTF-8', $param->{$_} ) for %$param;

    my $res =
      Plack::Response->new( 200, [ 'Content-Type' => 'application/json' ] );

    try {
        my $cql = $param->{query};
        my $db  = $param->{db};

        my $format = $param->{format} || 'plain';
        die "Format wird nicht unterstützt"
          if $format !~ /^(json|plain|plus|tsv|csv|table)$/;

        my $level;
        if ( my $l = $param->{level} ) {
            die [ 400, "Level darf nur 0, 1 oder 2 sein!\n" ]
              if $l !~ /^[012]$/;
            $level = sub { return pica_split( $_[0], $l ) };
        }

        my $reduce;
        if ( my $r = $param->{reduce} =~ s/\s+//mgr ) {
            $r      = [ map { path( $_, 0 ) } split /[|,]+/, $r ];
            $reduce = sub {
                return pica_fields( $_[0], @$r );
            };
        }

        my $filter = $param->{filter} =~ s/\s+|\s+//gr;
        $filter = filter($filter) if $filter;

        my $recs = $self->query( db => $db, cql => $cql );

        $recs = $recs->map($level)     if $level;
        $recs = $recs->select($filter) if $filter;
        $recs = $recs->map($reduce)    if $reduce;
        $recs = $recs->to_array;

        if ( $format eq 'json' ) {
            $res->body( json($recs) );
        }
        elsif ( $format =~ /^(plain|plus)$/ ) {
            my $body   = "";
            my $writer = pica_writer( $format, \$body );
            $writer->write($_) for @$recs;
            $writer->end;
            $res->header( 'Content-Type' => 'text/plain; encoding=UTF-8' );
            $body =~ s/\n+$/\n/s;  # FIXME: pica_writer emits additional newline
            $res->body( [$body] );
        }
        elsif ( $format =~ /^(tsv|csv|table)$/ ) {
            my $table =
              tabular( $recs, $param->{select}, $param->{separator} );

            if ( $format eq 'table' ) {
                $res->body(
                    json( $table, pretty => @{ $table->{rows} } < 100 ) );
            }
            else {
                my $body = '';
                my @opts = (
                    file   => \$body,
                    fields => [ map { $_->{name} } @{ $table->{fields} } ]
                );
                exporter( uc $format, @opts )->add_many( $table->{rows} );

                $res->header(
                      'Content-Type' => $format eq 'tsv'
                    ? 'text/tab-separated-values'
                    : 'text/csv'
                );
                $res->body( [$body] );
            }
        }
    }
    catch {
        my ( $code, $msg ) = ref $_ ? @$_ : ( 500, $_ );
        $msg =~ s/ at .+ line .+//sm unless $debug;
        $res->code($code);
        $res->body( json( { message => $msg, status => $code }, pretty => 1 ) );
    };

    return $res->finalize;
}

sub query {
    my ( $self, %param ) = @_;

    my $db = $self->databases->{ $param{db} || $self->{default_database} }
      or die [ 400, "Unbekannte oder fehlende Datenbank" ];

    my $cql = $param{cql} or die [ 400, "Fehlende CQL-Abfrage" ];

    my $limit = $param{limit} || 10;
    $limit = 1000 if $limit > 1000;

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

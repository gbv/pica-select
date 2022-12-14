use v5.20;

use lib 'lib';
use lib 'local/lib/perl5';

use Plack::Builder;
use Plack::App::File;
use Plack::Middleware::CrossOrigin;

use GBV::SRUSelect;
use JSON;

# load configuration
my %config;
for ( grep { -f $_ } qw(config.local.json config.json) ) {
    my $json = decode_json(
        do { local ( @ARGV, $/ ) = $_; <> }
    );
    %config = ( %config, %$json );
}

# build application
builder {
    enable 'CrossOrigin', origins => '*';

    # Client and static pages
    enable "Static",
      path         => sub { s!/?$}!/index.html! },
      root         => 'dist',
      pass_through => 1;
    mount '/' => Plack::App::File->new( root => 'dist' )->to_app;

    # API endpoints
    mount "/status" => sub {
        [
            200,
            [ 'Content-Type' => 'application/json' ],
            [ to_json( \%config, { pretty => 1, canonical => 1, utf8 => 1 } ) ]
        ]
    };
    mount "/select" => GBV::SRUSelect->new( \%config )->to_app;
}

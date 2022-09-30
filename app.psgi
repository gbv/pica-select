use v5.20;

use lib 'lib';
use lib 'local/lib/perl5';

use Plack::Builder;
use Plack::App::File;
use Plack::Middleware::CrossOrigin;

use GBV::SRUSelect;
use JSON;

my $client = "dist";

# load configuration
my %config;
for (grep { -f $_ } qw(config.local.json config.json)) {
    my $json = decode_json( do { local (@ARGV, $/) = $_; <> } );
    %config = ( %config, %$json );
}

# build application
builder {
    enable 'CrossOrigin', origins => '*';
    enable "Static",
        path         => sub { s!/?$}!/index.html! },
        root         => $client,
        pass_through => 1;
    mount '/' => Plack::App::File->new(root => $client)->to_app;
    mount "/select" => GBV::SRUSelect->new(\%config);
}

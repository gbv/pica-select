use v5.20;

use lib 'lib';
use lib 'local/lib/perl5';

use Plack::Builder;
use Plack::App::File;
use Plack::Middleware::CrossOrigin;

use GBV::SRUSelect;

my $app = GBV::SRUSelect->new(
    databases => {
        'opac-de-627' => {
            srubase => 'http://sru.k10plus.de/opac-de-627',
        },
        'dnb' => {
            srubase => 'https://services.dnb.de/sru/dnb'
        },
    },
    default_database => 'opac-de-627'
);

builder {
    enable "Static",
        path         => sub { s!/?$}!/index.html! },
        root         => 'client',
        pass_through => 1;
    mount '/' => Plack::App::File->new(root => 'client')->to_app;
    mount "/select" => builder {
        enable 'CrossOrigin', origins => '*';
        $app;
    };
}

use v5.20;

use lib 'lib';
use lib 'local/lib/perl5';

use Test::More;
use Plack::Test;
use HTTP::Request::Common qw(GET);
use JSON;

my $app = Plack::Test->create(do "./app.psgi");

my $res = $app->request(GET '/');
is $res->code, 200, '/';
like $res->content, qr/<html/;

$res = $app->request(GET '/status');
is $res->code, 200, '/status';
is ref from_json($res->content), 'HASH';

$res = $app->request(GET '/select');
is $res->code, 400, '/select (incomplete query)';
is from_json($res->content)->{message}, 'Fehlende CQL-Abfrage';

done_testing;

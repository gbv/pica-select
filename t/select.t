use v5.20;

use lib 'lib';
use lib 'local/lib/perl5';

use Test::More;
use GBV::SRUSelect;
use JSON;
use Catmandu qw(importer);

my $config = decode_json( do { local (@ARGV, $/) = "config.json"; <> } );
my $backend = GBV::SRUSelect->new($config);

sub query {
    my ($file, %query) = @_;
    *GBV::SRUSelect::query = sub { importer('PICA', type => 'plain', fh => $file) };
    return join '', @{$backend->select(\%query)->[2]};
}

my $pp = query('t/example.pp', format => 'pp');
my $res = importer('PICA', type => 'plain', fh => \$pp);
is @{$res->to_array}, 3, 'format=pp';

my $norm = query('t/example.pp', format => 'norm', levels => '01');
$res = importer('PICA', type => 'plus', fh => \$norm);
is @{$res->to_array}, 6, 'format=norm, levels=01';

my $json = query('t/example.pp', format => 'json', levels => '02');
$res = decode_json($json);
is @$res, 7, 'format=norm, levels=02';

my $tsv = query('t/example.pp', format => 'tsv', select => 'ppn: 003@ $0' );
is $tsv, "ppn\n1030386986\n161165839X\n786718889\n", "tsv";

my $table = query('t/example.pp', format => 'table', select => "ppn: 003@\$0\n032@\$a\n" );
is_deeply explain decode_json($table),
   {
      fields => [
        { name => 'ppn', value => '003@$0' },
        { name => '032@$a', value => '032@$a' }
      ],
      rows => [
         { '032@$a' => '3. Auflage', ppn => '1030386986' },
         { '032@$a' => '2. Aufl.', ppn => '161165839X' },
         { '032@$a' => '2. Aufl.', ppn => '786718889' }
      ]
   }, 'format=table';

done_testing;

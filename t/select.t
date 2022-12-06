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
    my (%query) = @_;
    *GBV::SRUSelect::query = sub { importer('PICA', type => 'plain', fh => "t/example.pp") };
    return join '', @{$backend->request(\%query)->[2]};
}

my $pp = query(format => 'plain');
my $res = importer('PICA', type => 'plain', fh => \$pp);
is @{$res->to_array}, 3, 'format=plain';

my $ppns = query(format => 'plain', reduce=>'003@');
is $ppns, "003@ \$01030386986\n\n003@ \$0161165839X\n\n003@ \$0786718889\n", "ppns";

my $plus = query(format => 'plus', level => '1');
$res = importer('PICA', type => 'plus', fh => \$plus);
is @{$res->to_array}, 6, 'format=plus, level=1';

my $json = query(format => 'json', level => '2');
$res = decode_json($json);
is @$res, 7, 'format=json, level=2';

my $tsv = query(format => 'tsv', select => "ppn: 003@ \$0\n lang:010@\$ac\n" );
is $tsv, "ppn\tlang\n1030386986\tger\n161165839X\tger\n786718889\tger\n", "tsv";

my $table = query(format => 'table', select => "ppn: 003@\$0\n032@\$a\n" );
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


my $csv = query(format => 'csv', select => "ppn:003@\$0", filter => "045Q/01\$a=='89.20'" );
is $csv, "ppn\n1030386986\n786718889\n", "filter (==)";

$csv = query(format => 'csv', select => "ppn:003@\$0", filter => "045Q/01\$a!='89.20'" );
is $csv, "ppn\n786718889\n", "filter (!=)";

done_testing;

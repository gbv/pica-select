use v5.20;

use lib 'lib';
use lib 'local/lib/perl5';

use Test::More;
use GBV::PICASelector;
use Catmandu qw(importer);

my $record = importer('PICA', type => 'plain', fh => "t/example.pp")->next;

my @tests = (
    '001U$0' => 'utf8',
    '001U $0' => 'utf8',
    '001U $0' => 'utf8',
    '002C $ab' => ['Text','txt'],
    '002C $a $b' => ['Text','txt'],
    '044K "$A, $D"' => 'Goldman, Emma',
    '044K "=$a"' => ['=','=Anarchismus'],
);

while (@tests) {
  my $syntax = shift @tests; 
  my $expect = shift @tests;
  my $selector = GBV::PICASelector->new($syntax);
  if (ref $expect) {
    is_deeply [ $selector->select_all($record) ], $expect, $syntax;
  } else {
    is $selector->select($record), $expect, $syntax;
  }
}

done_testing;

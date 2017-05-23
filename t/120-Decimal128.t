use v6;
use Test;

use BSON::Decimal128;

#-------------------------------------------------------------------------------
subtest 'init decimal128 nummerator/denominator', {
  my BSON::Decimal128 $d128 .= new( 2, 4);
  isa-ok $d128, BSON::Decimal128;

  is ~$d128, '0.5', 'can be coersed to string';
  is $d128 * 2.3, 1.15, 'calculations can be done directly';
  ok ($d128 * 2.3) ~~ FatRat, 'type of calculation is FatRat';

  ok +$d128 ~~ FatRat, 'object coersed to return FatRat';
  is-approx (cos +$d128), 0.877582, 'cosine on coersed object';

  ok ?$d128, 'd128 is not 0';
  $d128 .= new( 0, 234);
  nok ?$d128, 'd128 is 0';
  $d128 = BSON::Decimal128;
  nok ?$d128, 'd128 not defined';
}

#-------------------------------------------------------------------------------
subtest 'init decimal128 with Num and others', {
  my BSON::Decimal128 $d128 .= new(:num(1.34e4));
  is $d128, 13400.0, 'Num init ok';

  $d128 .= new(:rat(2/52));
  note +$d128;
  is-approx +$d128, 0.038462, 1e-5, 'Rat init ok';

  $d128 .= new(:str<12.345>);
  is +$d128, 12.345, 'Str init ok';
}

#-------------------------------------------------------------------------------
subtest 'encode decimal128', {
#  my Buf $b = BSON::Decimal128.encode(FatRat.new( 2, 1));
  my $a = 10;
}

#-------------------------------------------------------------------------------
done-testing

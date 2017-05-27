use v6;
use Test;

use BSON::Decimal128;

#-------------------------------------------------------------------------------
subtest 'd128 bcd', {
  my BSON::Decimal128 $d128 .= new(:str<234>);
  isa-ok $d128, BSON::Decimal128;

  is +$d128, 234, 'number returned ok';
  is-deeply $d128.bcd(123), Buf.new( 0x23, 0x01), 'BCD 123 ok';
  is-deeply $d128.bcd(709223), Buf.new( 0x23, 0x92, 0x70), 'BCD 709223 ok';
  is-deeply $d128.bcd('872'), Buf.new( 0x72, 0x08), "BCD '872' ok";
}

#-------------------------------------------------------------------------------
subtest 'd128 bcd8', {
  my BSON::Decimal128 $d128 .= new(:str<234>);
  is-deeply $d128.bcd8(7031), Buf.new( 1, 3, 0, 7), 'BCD8 7031 ok';
  is-deeply $d128.bcd8('872'), Buf.new( 2, 7, 8), "BCD8 '872' ok";
}

#-------------------------------------------------------------------------------
subtest 'd128 dpd', {
  my BSON::Decimal128 $d128 .= new(:str<234>);
  is-deeply $d128.bcd2dpd($d128.bcd8('245')), Buf.new( 0x02, 0xc2), 'dpd 245';
  is-deeply $d128.bcd2dpd($d128.bcd8('248')), Buf.new( 0x01, 0x4c), 'dpd 248';
  is-deeply $d128.bcd2dpd($d128.bcd8('295')), Buf.new( 0x02, 0xba), 'dpd 295';
  is-deeply $d128.bcd2dpd($d128.bcd8('298')), Buf.new( 0x01, 0x1e), 'dpd 298';
  is-deeply $d128.bcd2dpd($d128.bcd8('945')), Buf.new( 0x02, 0xc9), 'dpd 945';
  is-deeply $d128.bcd2dpd($d128.bcd8('948')), Buf.new( 0x02, 0x2f), 'dpd 948';
  is-deeply $d128.bcd2dpd($d128.bcd8('895')), Buf.new( 0x02, 0xde), 'dpd 895';
  is-deeply $d128.bcd2dpd($d128.bcd8('898')), Buf.new( 0x00, 0x7e), 'dpd 898';

  is-deeply $d128.bcd2dpd($d128.bcd8('945898')),
            Buf.new( 0x01, 0xfa, 0xc9), 'dpd 945898';
}

#-------------------------------------------------------------------------------
subtest 'init decimal128 nummerator/denominator', {
  my BSON::Decimal128 $d128 .= new( 2, 4);

  like ~$d128, /^ '0.5' /, 'can be coersed to string';
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
  is +$d128, 13400.0, 'Num init ok';

  $d128 .= new(:rat(2/52));
  is-approx +$d128, 0.038462, 1e-5, 'Rat init ok';

  $d128 .= new(:str<12.345>);
  is +$d128, 12.345, 'Str init ok';
}

#-------------------------------------------------------------------------------
subtest 'encode decimal128', {
  my BSON::Decimal128 $d128 .= new(:num(Inf));
  my Buf $b = $d128.encode;
  is-deeply $b, Buf.new( 0x78, 0x00 xx 15), 'Inf ok';

  $d128 .= new(:num(-Inf));
  $b = $d128.encode;
  is-deeply $b, Buf.new( 0xf8, 0x00 xx 15), '-Inf ok';

  $d128 .= new(:num(NaN));
  $b = $d128.encode;
  is-deeply $b, Buf.new( 0x7c, 0x00 xx 15), 'NaN ok';

}

#-------------------------------------------------------------------------------
done-testing

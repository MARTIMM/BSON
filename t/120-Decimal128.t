use v6;
use Test;

use BSON::Decimal128;

#`{{
#-------------------------------------------------------------------------------
subtest 'd128 bcd', {
  my BSON::Decimal128 $d128 .= new(:str<234>);
  isa-ok $d128, BSON::Decimal128;

  is +$d128, 234, 'number returned ok';
  is-deeply $d128.bcd(123), Buf.new( 0x23, 0x01), 'BCD 123 ok';
  is-deeply $d128.bcd(709223), Buf.new( 0x23, 0x92, 0x70), 'BCD 709223 ok';
  is-deeply $d128.bcd('872'), Buf.new( 0x72, 0x08), "BCD '872' ok";
}
}}

#-------------------------------------------------------------------------------
subtest 'd128 bcd8', {
  my BSON::Decimal128 $d128 .= new(:str<234>);
  is-deeply $d128.bcd8(7031), Buf.new( 1, 3, 0, 7), 'BCD8 7031 ok';
  is-deeply $d128.bcd8('872'), Buf.new( 2, 7, 8), "BCD8 '872' ok";
}

#-------------------------------------------------------------------------------
subtest 'd128 dpd', {
  my BSON::Decimal128 $d128 .= new(:str<234>);
  is-deeply $d128.bcd2dpd($d128.bcd8('245')), Buf.new( 0x45, 0x01), 'dpd 245';
  is-deeply $d128.bcd2dpd($d128.bcd8('248')), Buf.new( 0x48, 0x01), 'dpd 248';
  is-deeply $d128.bcd2dpd($d128.bcd8('295')), Buf.new( 0x5b, 0x01), 'dpd 295';
  is-deeply $d128.bcd2dpd($d128.bcd8('298')), Buf.new( 0x5e, 0x01), 'dpd 298';
  is-deeply $d128.bcd2dpd($d128.bcd8('945')), Buf.new( 0xcd, 0x02), 'dpd 945';
  is-deeply $d128.bcd2dpd($d128.bcd8('948')), Buf.new( 0xae, 0x02), 'dpd 948';
  is-deeply $d128.bcd2dpd($d128.bcd8('895')), Buf.new( 0x1f, 0x02), 'dpd 895';
  is-deeply $d128.bcd2dpd($d128.bcd8('898')), Buf.new( 0x7e, 0x00), 'dpd 898';

  # tests from table on wiki
  is-deeply $d128.bcd2dpd($d128.bcd8('005')), Buf.new( 0x05, 0x00), 'dpd 005';
  is-deeply $d128.bcd2dpd($d128.bcd8('009')), Buf.new( 0x09, 0x00), 'dpd 009';
  is-deeply $d128.bcd2dpd($d128.bcd8('055')), Buf.new( 0x55, 0x00), 'dpd 055';
  is-deeply $d128.bcd2dpd($d128.bcd8('079')), Buf.new( 0x79, 0x00), 'dpd 079';
  is-deeply $d128.bcd2dpd($d128.bcd8('080')), Buf.new( 0x0a, 0x00), 'dpd 080';
  is-deeply $d128.bcd2dpd($d128.bcd8('099')), Buf.new( 0x5f, 0x00), 'dpd 099';
  is-deeply $d128.bcd2dpd($d128.bcd8('555')), Buf.new( 0xd5, 0x02), 'dpd 555';
  is-deeply $d128.bcd2dpd($d128.bcd8('999')), Buf.new( 0xff, 0x00), 'dpd 999';

  is-deeply $d128.bcd2dpd($d128.bcd8('945898')),
            Buf.new( 0x7e, 0x34, 0x0b), 'dpd 945898';
}

done-testing;
=finish

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

  $d128 .= new(:num(1e0));
  $b = $d128.encode;
  is-deeply $b, Buf.new(
    0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0x30
  ), '1';

#`{{
  $d128 .= new( 2, 1);
  $b = $d128.encode;
  is-deeply $b, Buf.new(
      0x10, 0xd0, 0x3c, 0xf1, 0xfd, 0x7f, 0x00, 0x00,
      0x80, 0x05, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00
    ),
    '2';

  $d128 .= new( 9999999999999999455752309870428160, 1);
  $b = $d128.encode;
  is-deeply $b, Buf.new(
      0xb0, 0xf6, 0xf1, 0x74, 0xff, 0x7f, 0x00, 0x00,
      0x80, 0x05, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00
    ),
    '9999999999999999455752309870428160';
}}
}

#-------------------------------------------------------------------------------
done-testing;

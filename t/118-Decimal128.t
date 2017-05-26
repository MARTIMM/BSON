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

  is-deeply $d128.bcd8(7031), Buf.new( 1, 3, 0, 7), 'BCD8 7031 ok';
  is-deeply $d128.bcd8('872'), Buf.new( 2, 7, 8), "BCD8 '872' ok";

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
done-testing;

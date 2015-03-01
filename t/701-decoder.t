use v6;
use Test;
use BSON::Decoder;

#-------------------------------------------------------------------------------
#
my BSON::Decoder $d1 .= new;
#say "d1: {$d1.^name}, $d1";
#say "d1: {$d1.perl}";
#say "d1: ", $d1.^methods;

my Buf $b = Buf.new( 0x01,                              # Double
                     0x62, 0x63, 0x64, 0x00,            # 'bcd' + 0
                     0x55, 0x55, 0x55, 0x55,            # 8 byte double
                     0x55, 0x55, 0xD5, 0x3F
                   );
$d1.decode($b.list);

is( $d1.code, $BSON::Decoder::DOUBLE, 'BSON Double');
is( $d1.value.^name, 'Num', 'Perl Num type');
is_approx( $d1.value, 0.3333333, 'Test nummeric value');

#say "d1: {$d1.code}, {$d1.value.^name}, \{{$d1.key} => {$d1.value}\}";

#-------------------------------------------------------------------------------
# Cleanup
#
done();
exit(0);

use v6;
use Test;
use BSON::EDC;

my Buf $doc = Buf.new( 0x26, 0x00, 0x00, 0x00,          # Total size    
                       0x01,                            # Double        
                       0x62, 0x00,                      # 'b' + 0       
                       0x55, 0x55, 0x55, 0x55,          # 8 byte double 
                       0x55, 0x55, 0xD5, 0x3F,
                       0x01,                            # Double        
                       0x63, 0x00,                      # 'c' + 0       
                       0x55, 0x55, 0x55, 0x55,          # 8 byte double 
                       0x55, 0x55, 0xD5, 0x3F,
                       0x01,                            # Double        
                       0x64, 0x00,                      # 'd' + 0       
                       0x55, 0x55, 0x55, 0x55,          # 8 byte double 
                       0x55, 0x55, 0xD5, 0x3F,
                       0x00                             # + 0           
                     );

my BSON::Encodable $e .= new;
my Hash $h = $e.decode($doc);
#say "H: ", $h.perl;

#is $e.bson_code, 0x01, 'Code = Double = 1';
ok $h<b>:exists, 'Var name "b" exists';
ok $h<c>:exists, 'Var name "c" exists';
ok $h<d>:exists, 'Var name "d" exists';
is $h<b>, Num(1/3), "Data of b is 1/3";
is $h<c>, Num(1/3), "Data of c is 1/3";
is $h<d>, Num(1/3), "Data of d is 1/3";

my Buf $b = $e.encode($h);
#say "B: ", $b;

is_deeply $doc.list, $b.list, 'Buffers are equal';

#-------------------------------------------------------------------------------
# Cleanup
#
done();
exit(0);



#-------------------------------------------------------------------------------
# Double precision floating point tests. See also the wikipedia at
# http://en.wikipedia.org/wiki/Double-precision_floating-point_format
# All binary arrays are little endian.
#-------------------------------------------------------------------------------

use v6;
use Test;
use BSON;

#-------------------------------------------------------------------------------
# 
my $bson = BSON.new;
my Buf $b;
my Buf $br;
my Num $v;

#-------------------------------------------------------------------------------
# Test special cases
#
# 0x0000 0000 0000 0000 = 0
# 0x8000 0000 0000 0000 = -0            Will become 0.
# 0x7FF0 0000 0000 0000 = Inf
# 0xFFF0 0000 0000 0000 = -Inf
#
$b = Buf.new( 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00);
$v = $bson._dec_double($b.list);
is $v, 0, 'Result is 0';
$br = $bson._enc_double($v);
is_deeply $br, $b, "special case $v after encode";

$b = Buf.new( 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00);
$v = $bson._dec_double($b.list);
is $v, Num.new(-0), 'Result is -0';
$br = $bson._enc_double($v);
is_deeply $br, Buf.new(0 xx 8), "special case -0 not recognizable and becomes 0";


$b = Buf.new( 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x7F);
$v = $bson._dec_double($b.list);
is $v, Inf, 'Result is Infinite';
$br = $bson._enc_double($v);
is_deeply $br, $b, "special case $v after encode";

$b = Buf.new( 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0xFF);
$v = $bson._dec_double($b.list);
is $v, -Inf, 'Result is minus Infinite';
$br = $bson._enc_double($v);
is_deeply $br, $b, "special case $v after encode";


#-------------------------------------------------------------------------------
# 0x3FD5 5555 5555 5555
# 0.33333333333333
# ~ 1/3
#
# Number 1/3
#
#`{{}}
$b = Buf.new( 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xD5, 0x3F);
$v = $bson._dec_double($b.list);
$br = $bson._enc_double(Num.new(1/3));
say "Br: ", $br;
is_deeply $br, $b, 'Compare bufs';
is $v, 0.333333333333333, "Result $v = 0.333333333333333";

# Number -1.34277290539414e+242, Big and negative
#
$b = Buf.new( 0x40, 0x47, 0x5A, 0xAC, 0x34, 0x23, 0x34, 0xF2);
#say "B: ", $b;
$v = $bson._dec_double($b.list);
say " -> $v, 0x40, 0x47, 0x5a, 0xac, 0x34, 0x23, 0x34, 0xf2";
$br = $bson._enc_double($v);
#say "BR: ", $br;
is_deeply $br, $b, "$v after encode";


# Number 40, Small and positive
#
$b = Buf.new( 0x00 xx 6, 0x44, 0x40);
#say "B: ", $b;
$v = $bson._dec_double($b.list);
say " -> $v";
$br = $bson._enc_double($v);
#say "BR: ", $br;
is_deeply $br, $b, "$v after encode";

#`{{}}
# Number -203.345, Small and negative
#
$b = Buf.new( 0xd7, 0xa3, 0x70, 0x3d, 0x0a, 0x6b, 0x69, 0xc0);
#say "B: ", $b;
$v = $bson._dec_double($b.list);
say " -> $v";
$br = $bson._enc_double($v);
#say "BR: ", $br;
is_deeply $br, $b, "$v after encode";

# Number 3E-100, Very small and positive
#
$b = $bson._enc_double(3E-100);
say "B: ", $b;

#$b = Buf.new( 0xE4, 0x83, 0x6A, 0x2B, 0x63, 0xFF, 0x44, 0x2B);
$v = $bson._dec_double($b.list);
say " -> $v";
$br = $bson._enc_double($v);
say "BR: ", $br;
is_deeply $br, $b, "$v after encode";


#-------------------------------------------------------------------------------
# Cleanup
#
done();
exit(0);

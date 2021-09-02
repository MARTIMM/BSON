use v6;
use Test;
use NativeCall;

use BSON::Binary;
use BSON::Document;
use BSON::Encode;
use BSON::Decode;

#-------------------------------------------------------------------------------
my BSON::Encode $encoder;
my BSON::Decode $decoder;

#-------------------------------------------------------------------------------
subtest "Encoded buf checks", {

  my BSON::Document $d .= new: ('a' ... 'd') Z=> 121..124;
  is $d<a>, 121, "\$<a> = $d<a>";
  is $d.keys, <a b c d>, 'keys a, b, c, d';

  # keys 'a'..'d' are cstring => 0xnn 0x00
  # 121..124 are numbers in size int32 => bson code 0x10
  #
  my Buf $etst = Buf.new(
    0x21, 0x00 xx 3,
    0x10, 0x61, 0x00, 0x79, 0x00, 0x00, 0x00,   # 10 'a' 121
    0x10, 0x62, 0x00, 0x7a, 0x00, 0x00, 0x00,   # 10 'b' 122
    0x10, 0x63, 0x00, 0x7b, 0x00, 0x00, 0x00,   # 10 'c' 123
    0x10, 0x64, 0x00, 0x7c, 0x00, 0x00, 0x00,   # 10 'd' 124
    0x00
  );

  my Buf $edoc = $d.encode;
  is-deeply $edoc, $etst, 'Encoded document is correct';


  is $d<b>:delete, 122, '$d<b> deleted';
  is $d.keys, <a c d>, 'keys a, c, d';

  $etst = Buf.new(
    0x1a, 0x00 xx 3,
    0x10, 0x61, 0x00, 0x79, 0x00, 0x00, 0x00,   # 10 'a' 121
    0x10, 0x63, 0x00, 0x7b, 0x00, 0x00, 0x00,   # 10 'c' 123
    0x10, 0x64, 0x00, 0x7c, 0x00, 0x00, 0x00,   # 10 'd' 124
    0x00
  );
  $edoc = $d.encode;
  is-deeply $edoc, $etst, 'Encoded document still correct after deletion';


  $d<b> = 2663;
  is $d<b>, 2663, '$d<b> added at end';
  is $d.keys, <a c d b>, 'keys a, c, d, b';

  $etst = Buf.new(
    0x21, 0x00 xx 3,
    0x10, 0x61, 0x00, 0x79, 0x00, 0x00, 0x00,   # 10 'a' 121
    0x10, 0x63, 0x00, 0x7b, 0x00, 0x00, 0x00,   # 10 'c' 123
    0x10, 0x64, 0x00, 0x7c, 0x00, 0x00, 0x00,   # 10 'd' 124
    0x10, 0x62, 0x00, 0x67, 0x0a, 0x00, 0x00,   # 10 'b' 2663
    0x00
  );

  $edoc = $d.encode;
  is-deeply $edoc, $etst, 'Encoded document still correct after addition';


  my Buf $new-data = Buf.new(
    0x2d, 0x00 xx 3,
    0x10, 0x6b, 0x65, 0x79, 0x30, 0x00, 0x7a, 0x00 xx 3,   # 10 'key0' 122
    0x10, 0x6b, 0x65, 0x79, 0x31, 0x00, 0x7b, 0x00 xx 3,   # 10 'key1' 123
    0x10, 0x6b, 0x65, 0x79, 0x32, 0x00, 0x7c, 0x00 xx 3,   # 10 'key2' 124
    0x10, 0x6b, 0x65, 0x79, 0x33, 0x00, 0x7d, 0x00 xx 3,   # 10 'key3' 125
    0x00
  );

  $d .= new($new-data);
#note "\nDoc; ", '-' x 75, $d.raku, '-' x 80;

  is $d<key0>, 122, "\$d<key0> => $d<key0>";



  my BSON::Document $d0;
  my BSON::Document $d1;
  my Buf $b;

  $d0 .= new: ( :a(10), :11b);   # List of Pair
  is $d0.elems, 2, '2 pairs added';
#note "\nDoc d0 ", '-' x 73, $d0.raku, '-' x 80;

  $encoder .= new;
  $b = $encoder.encode($d0);
#note $b;
  is-deeply $b[*],
    <13 00 00 00 10 61 00 0A 00 00 00 10 62 00 0B 00 00 00 00>
      .map( { :16($_); } ), 'Buf content';
};

#-------------------------------------------------------------------------------
subtest "Encode / Decode", {
  my BSON::Document $d0;
  my BSON::Document $d1;
  my Buf $b;

  $encoder .= new;

  $d0 .= new: ( :a(10), :11b);   # List of Pair
  is $d0.elems, 2, '2 pairs added';
#note "\nDoc d0 ", '-' x 73, $d0.raku, '-' x 80;

  $encoder .= new;
  $b = $encoder.encode($d0);
  $decoder .= new;
  $d1 = $decoder.decode($b);
  is-deeply $d0, $d1, '1st .encode() / .decode()';

  $d0 .= new: ( :a(10), :11b, :x( :p<abc>, :q<def>));
#note "\nDoc d0 ", '-' x 73, $d0.raku, '-' x 80;
  $b = $encoder.encode($d0);
#note $b;
  $decoder .= new;
  $d1 = $decoder.decode($b);
#note "\nDoc d1 ", '-' x 73, $d1.raku, '-' x 80;
  is-deeply $d0, $d1, '2nd .encode() / .decode()';


  $d0 .= new: ( :a(10), :b([10, 11, :x(:b<hgf>)]), :y( :p<abc>, :q<def>));
#note "\nDoc d0 ", '-' x 73, $d0.raku, '-' x 80;
  $b = $encoder.encode($d0);
#note $b;
  $decoder .= new;
  $d1 = $decoder.decode($b);
  is-deeply $d0, $d1, '3rd .encode() / .decode()';
#note "\nDoc d1 ", '-' x 73, $d1.raku, '-' x 80;

  $d1 .= new($b);
  is-deeply $d0, $d1, '.new(Buf)';
#note "\nDoc d1 ", '-' x 73, $d1.raku, '-' x 80;

#note $d0.decode($b);
#  my BSON::Document $d2 .= new($d0.decode($b));
#  is $d2<b>, 11, 'encode/decode d2';
#note "\nDoc d2 ", '-' x 73, $d2.raku, '-' x 80;
}

#-------------------------------------------------------------------------------
subtest 'encoding CArray[byte]', {

  my BSON::Document $bson .= new: (
    :int-number(-10),
    :num-number(-2.34e-3),
    strings => BSON::Document.new(( :s1<abc>, :s2<def>, :s3<xyz> ))
  );

  # And store it in a native array of bytes
  my $bytes = $bson.encode(:carray);

  my BSON::Document $bson2 .= new($bytes);
  is-deeply
    ( $bson2<int-number>, $bson2<num-number>, $bson2<strings><s2>),
    ( -10, -234e-5, 'def'), '.new(CArray[byte])';

  my BSON::Document $bson3 = BSON::Document.decode($bytes);
    is-deeply
    ( $bson2<int-number>, $bson2<num-number>, $bson2<strings><s2>),
    ( -10, -234e-5, 'def'), 'BSON::Document.decode(CArray[byte])';
}

#-------------------------------------------------------------------------------
subtest 'private binary of a complex number', {
  # My own complex number type
  enum MyBinDataTypes ( :COMPLEX(0x80));
  my Complex $c = 2.4 + 3.3i;
  my Buf $data .= new;
  $data.write-num64( 0, $c.re, LittleEndian);
  $data.write-num64( BSON::C-DOUBLE-SIZE, $c.im, LittleEndian);
  is $data.elems, 2 * BSON::C-DOUBLE-SIZE, 'size of Buf ok';

  my BSON::Document $d1 .= new: (
    :bin-complex(BSON::Binary.new( :$data, :type(COMPLEX)))
  );

  my Buf $cb = $d1.encode;
  my BSON::Document $d2 .= new($cb);
  is $d2<bin-complex>.binary-type, COMPLEX.value, 'binary type ok';
  is $d2<bin-complex>.binary-data.elems, 2 * BSON::C-DOUBLE-SIZE, 'size ok';
  my Complex $c2 .= new(
    $d2<bin-complex>.binary-data.read-num64( 0, LittleEndian),
    $d2<bin-complex>.binary-data.read-num64( BSON::C-DOUBLE-SIZE, LittleEndian)
  );
  is $c2.re, 24e-1, 'real part ok';
  is $c2.im, 33e-1, 'imaginary part ok';


#note "\nDoc d2 ", '-' x 73, $d2.raku, '-' x 80;

}

#-------------------------------------------------------------------------------
done-testing;
=finish

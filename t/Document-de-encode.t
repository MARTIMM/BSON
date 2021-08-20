use v6;
use Test;
#use NativeCall;

use BSON::Document;
use BSON::Encode;
use BSON::Decode;

#-------------------------------------------------------------------------------
my BSON::Encode $encoder;
my BSON::Decode $decoder;

#-------------------------------------------------------------------------------
subtest "Document encode", {
  my BSON::Document $d0;
  my BSON::Document $d1;
  my Buf $b;

  $encoder .= new;

  $d0 .= new: ( :a(10), :11b);   # List of Pair
  is $d0.elems, 2, '2 pairs added';
note "\nDoc d0 ", '-' x 73, $d0.raku, '-' x 80;

  $encoder .= new;
  $b = $encoder.encode($d0);
#note $b;
  is-deeply $b[*],
    <13 00 00 00 10 61 00 0A 00 00 00 10 62 00 0B 00 00 00 00>.map( {
        :16($_);
      }
    ), 'Buf content';

  $decoder .= new;
  $d1 = $decoder.decode($b);

#  my BSON::Document $d1 .= new($b);
#  is $d1<b>, 11, 'encode/decode d1';
note "\nDoc d1 ", '-' x 73, $d1.raku, '-' x 80;

#note $d0.decode($b);
#  my BSON::Document $d2 .= new($d0.decode($b));
#  is $d2<b>, 11, 'encode/decode d2';
#note "\nDoc d2 ", '-' x 73, $d2.raku, '-' x 80;


  $d0 .= new: ( :a(10), :11b, :x( :p<abc>, :q<def>));
note "\nDoc d0 ", '-' x 73, $d0.raku, '-' x 80;
  $b = $encoder.encode($d0);
#note $b;
  $decoder .= new;
  $d1 = $decoder.decode($b);
note "\nDoc d1 ", '-' x 73, $d1.raku, '-' x 80;


  $d0 .= new: ( :a(10), :b([10, 11, :x(:b<hgf>)]), :y( :p<abc>, :q<def>));
note "\nDoc d0 ", '-' x 73, $d0.raku, '-' x 80;
  $b = $encoder.encode($d0);
#note $b;
  $decoder .= new;
  $d1 = $decoder.decode($b);
note "\nDoc d1 ", '-' x 73, $d1.raku, '-' x 80;
}

#-------------------------------------------------------------------------------
done-testing;
=finish

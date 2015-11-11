use v6;
use Test;
use BSON::Document;

#-------------------------------------------------------------------------------
subtest {

  my BSON::Document $d .= new: ('a' ... 'd') Z=> 121..124;
  is $d<a>, 121, "\$<a> = $d<a>";

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

}, "Document encoding associative";

#-------------------------------------------------------------------------------
subtest {

  my BSON::Document $d .= new;
  $d[0] = 122;
  $d[1] = 123;
  $d[2] = 124;
  $d[3] = 125;
  is $d[2], 124, "\$d[2] = $d[2]";
  is $d<key2>, 124, "\$d<key2> = $d<key2>";

  my Buf $etst = Buf.new(
    0x2d, 0x00 xx 3,
    0x10, 0x6b, 0x65, 0x79, 0x30, 0x00, 0x7a, 0x00 xx 3,   # 10 'key0' 122
    0x10, 0x6b, 0x65, 0x79, 0x31, 0x00, 0x7b, 0x00 xx 3,   # 10 'key1' 123
    0x10, 0x6b, 0x65, 0x79, 0x32, 0x00, 0x7c, 0x00 xx 3,   # 10 'key2' 124
    0x10, 0x6b, 0x65, 0x79, 0x33, 0x00, 0x7d, 0x00 xx 3,   # 10 'key3' 125
    0x00
  );

  my Buf $edoc = $d.encode;
  is-deeply $edoc, $etst, 'Encoded document is correct';


  $d[2]:delete;
  $etst = Buf.new(
    0x23, 0x00 xx 3,
    0x10, 0x6b, 0x65, 0x79, 0x30, 0x00, 0x7a, 0x00 xx 3,   # 10 'key0' 122
    0x10, 0x6b, 0x65, 0x79, 0x31, 0x00, 0x7b, 0x00 xx 3,   # 10 'key1' 123
    0x10, 0x6b, 0x65, 0x79, 0x33, 0x00, 0x7d, 0x00 xx 3,   # 10 'key3' 125
    0x00
  );

  $edoc = $d.encode;
  is-deeply $edoc, $etst, 'Encoded document is correct after deletion';

  # Generated key is key3. Already there so modifies instead of adding.
  #
  $d[3] = 10;
  is $d[2], 10, "\$d[2] = $d[2]";
  is $d<key3>, 10, "\$d<key3> = $d<key3>";
  $etst = Buf.new(
    0x23, 0x00 xx 3,
    0x10, 0x6b, 0x65, 0x79, 0x30, 0x00, 0x7a, 0x00 xx 3,   # 10 'key0' 122
    0x10, 0x6b, 0x65, 0x79, 0x31, 0x00, 0x7b, 0x00 xx 3,   # 10 'key1' 123
    0x10, 0x6b, 0x65, 0x79, 0x33, 0x00, 0x0a, 0x00 xx 3,   # 10 'key3' 10
    0x00
  );

  $edoc = $d.encode;
  is-deeply $edoc, $etst, 'Encoded document is correct after modifying';

  # Generated key is key20. Not there so adds. But only after adding a new entry
  #
  $d<a> = 1;
  $d[20] = 11;
  is $d[4], 11, "\$d[4] = $d[4]";
  is $d<key20>, 11, "\$d<key20> = $d<key20>";
  $etst = Buf.new(
    0x35, 0x00 xx 3,
    0x10, 0x6b, 0x65, 0x79, 0x30, 0x00, 0x7a, 0x00 xx 3,   # 10 'key0' 122
    0x10, 0x6b, 0x65, 0x79, 0x31, 0x00, 0x7b, 0x00 xx 3,   # 10 'key1' 123
    0x10, 0x6b, 0x65, 0x79, 0x33, 0x00, 0x0a, 0x00 xx 3,   # 10 'key3' 10
    0x10, 0x61, 0x00, 0x01, 0x00 xx 3,                     # 10 'a' 1
    0x10, 0x6b, 0x65, 0x79, 0x32, 0x30, 0x00, 0x0b, 0x00 xx 3,
                                                           # 10 'key20' 11
    0x00
  );

  $edoc = $d.encode;
#say $edoc;
  is-deeply $edoc, $etst, 'Encoded document is correct after adding';

}, "Document encoding positional";

#-------------------------------------------------------------------------------
subtest {
  my BSON::Document $d .= new;
  my Buf $new-data = Buf.new(
    0x2d, 0x00 xx 3,
    0x10, 0x6b, 0x65, 0x79, 0x30, 0x00, 0x7a, 0x00 xx 3,   # 10 'key0' 122
    0x10, 0x6b, 0x65, 0x79, 0x31, 0x00, 0x7b, 0x00 xx 3,   # 10 'key1' 123
    0x10, 0x6b, 0x65, 0x79, 0x32, 0x00, 0x7c, 0x00 xx 3,   # 10 'key2' 124
    0x10, 0x6b, 0x65, 0x79, 0x33, 0x00, 0x7d, 0x00 xx 3,   # 10 'key3' 125
    0x00
  );
  $d.decode($new-data);
  
  is $d<key0>, 122, "\$d<key0> => $d<key0>";

}, "Document decoding";

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing();
exit(0);

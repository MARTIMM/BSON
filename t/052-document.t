use v6;
use Test;
use BSON::Document;

#-------------------------------------------------------------------------------
subtest {

  my BSON::Document $d .= new;

  $d<b> = -203.345.Num;
  $d<a> = 1234;

  # keys 'a'..'d' are cstring => 0xnn 0x00
  # 121..124 are numbers in size int32 => bson code 0x10
  #
  my Buf $etst = Buf.new(
    0x17, 0x00 xx 3,
    0x01, 0x62, 0x00, 0xd7, 0xa3, 0x70, 0x3d, 0x0a, 0x6b, 0x69, 0xc0,
                                                # 01 'b' -203.345
    0x10, 0x61, 0x00, 0xd2, 0x04, 0x00, 0x00,   # 10 'a' 1234
    0x00
  );

  my Buf $edoc = $d.encode;
  is-deeply $edoc, $etst, 'Encoded document is correct';

  # Fresh doc
  #
  diag "Sequence of keys";

  $d .= new;
  $d.decode($etst);
  is $d<a>, 1234, "a => $d<a>, int32";
  is $d<b>, -203.345, "b => $d<b>, double";

  # Test sequence
  #
  diag "Sequence of index";

  is $d[0], -203.345.Num, "0: $d[0], double";
  is $d[1], 1234, "1: $d[1], int32";

}, "Document encoding decoding types";

#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing();
exit(0);

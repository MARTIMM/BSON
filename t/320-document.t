use v6;
use Test;
use BSON::Document;
use BSON::Javascript;

#-------------------------------------------------------------------------------
subtest {

  my BSON::Javascript $js .= new(
    :javascript('function(x){return x;}')
  );

  my BSON::Javascript $js-scope .= new(
    :javascript('function(x){return x;}'),
    :scope(Document.new: (nn => 10, a1 => 2))
  );

  # Tests of
  #
  # 0x01 Double
  # 0x03 Document
  # 0x0D Javascript
  # 0x0F Javascript with scope
  # 0x10 int32
  # 0x12 int64
  #
  my BSON::Document $d .= new;

  # Filling with data
  #
  $d<b> = -203.345.Num;
  $d<a> = 1234;
  $d<v> = 4295392664;
  $d<w> = $js;
  $d<abcdef> = a1 => 10, bb => 11;
  $d<abcdef><b1> = q => 255;
  $d<jss> = $js-scope;

say $d.encode;

  # Handcrafted encoded BSON data
  #
  my Buf $etst = Buf.new(
    # 157 (4 + 11 + 7 + 11 + 30 + 45 + 48 + 1)
    0x6d, 0x00, 0x00, 0x00,                     # Size document

    # 11
    BSON::C-DOUBLE,                             # 0x01
      0x62, 0x00,                               # 'b'
      0xd7, 0xa3, 0x70, 0x3d,                   # -203.345
      0x0a, 0x6b, 0x69, 0xc0,

    # 7
    BSON::C-INT32,                              # 0x10
      0x61, 0x00,                               # 'a'
      0xd2, 0x04, 0x00, 0x00,                   # 1234

    # 11
    BSON::C-INT64,                              # 0x12
      0x76, 0x00,                               # 'v'
      0x98, 0x7d, 0x06, 0x00,                   # 4295392664
      0x01, 0x00, 0x00, 0x00,

    # 30
    BSON::C-JAVASCRIPT,                         # 0x0D
      0x77, 0x00,                               # 'w'
      0x17, 0x00, 0x00, 0x00,                   # 23 bytes js code + 1
      0x66, 0x75, 0x6e, 0x63, 0x74, 0x69,       # UTF8 encoded Javascript
      0x6f, 0x6e, 0x28, 0x78, 0x29, 0x7b,       # 'function(x){return x;}'
      0x72, 0x65, 0x74, 0x75, 0x72, 0x6e,
      0x20, 0x78, 0x3b, 0x7d, 0x00,

    # 45 (37 + 8)
    BSON::C-DOCUMENT,                           # 0x03
      0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x00, # 'abcdef'

      # 37 (4 + 8 + 8 + 16 + 1)
      0x25, 0x00, 0x00, 0x00,                   # Size nested document

      # 8
      BSON::C-INT32,                            # 0x10
        0x61, 0x31, 0x00,                       # 'a1'
        0x0a, 0x00, 0x00, 0x00,                 # 10

      # 8
      BSON::C-INT32,                            # 0x10
        0x62, 0x62, 0x00,                       # 'bb'
        0x0b, 0x00, 0x00, 0x00,                 # 11

      # 16 (12 + 4)
      BSON::C-DOCUMENT,                         # 0x03
        0x62, 0x31, 0x00,                       # 'b1'

        # 12 (4 + 7 + 1)
        0x0c, 0x00, 0x00, 0x00,                 # Size nested document

        # 7
        BSON::C-INT32,                          # 0x10
          0x71, 0x00,                           # 'q'
          0xff, 0x00, 0x00, 0x00,               # 255

        0x00,                                   # End nested document

      0x00,                                     # End nested document

    # 48 (32 + 16)
    C-JAVASCRIPT-SCOPE,                         # 0x0F
      0x6a, 0x73, 0x73, 0x00,                   # 'jss'
      0x17, 0x00, 0x00, 0x00,                   # 23 bytes js code + 1
      0x66, 0x75, 0x6e, 0x63, 0x74, 0x69,       # UTF8 encoded Javascript
      0x6f, 0x6e, 0x28, 0x78, 0x29, 0x7b,       # 'function(x){return x;}'
      0x72, 0x65, 0x74, 0x75, 0x72, 0x6e,
      0x20, 0x78, 0x3b, 0x7d, 0x00,

      # 16 (21 + 1)                             # No key encoded
      BSON::C-DOCUMENT,                         # 0x03

        # 21 (4 + 8 + 8 + 1)
        0x15, 0x00, 0x00, 0x00,                 # Size nested document

        # 8
        BSON::C-INT32,                          # 0x10
          0x6e, 0x6e, 0x00,                     # 'nn'
          0x0a, 0x00, 0x00, 0x00,               # 10

        # 8
        BSON::C-INT32,                          # 0x10
          0x61, 0x31, 0x00,                     # 'a1'
          0x02, 0x00, 0x00, 0x00,               # 2

      0x00,                                     # End nested document

    0x00                                        # End document
  );

  # Encode document and compare with handcrafted byte array
  #
  my Buf $edoc = $d.encode;
  is-deeply $edoc, $etst, 'Encoded document is correct';

  # Fresh doc, load handcrafted data and decode into document
  #
  diag "Sequence of keys";

  $d .= new;
  $d.decode($etst);
  is $d<a>, 1234, "a => $d<a>, int32";
  is $d<b>, -203.345, "b => $d<b>, double";
  is $d<v>, 4295392664, "v => $d<v>, int64";

  is $d<w>.^name, 'Javascript', 'Javascript code on $d<w>';
  is $d<w>.javascript, 'function(x){return x;}', 'Code is same';

  is $d<abcdef><a1>, 10, "nest \$d<abcdef><a1> = $d<abcdef><a1>";
  is $d<abcdef><b1><q>, 255, "nest \$d<abcdef><b1><q> = $d<abcdef><b1><q>";


  # Test sequence
  #
  diag "Sequence of index";

  is $d[0], -203.345.Num, "0: $d[0], double";
  is $d[1], 1234, "1: $d[1], int32";
  is $d[2], 4295392664, "1: $d[2], int64";

}, "Document encoding decoding types";

#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing();
exit(0);

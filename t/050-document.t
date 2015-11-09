use v6;
use Test;
use BSON::Document;

#-------------------------------------------------------------------------------
subtest {

  my BSON::Document $d .= new: ('a' ... 'z') Z=> 120..145;
  is $d.^name, 'Document', 'Isa ok';
  
  is $d<a>, 120, "\$d<a> = $d<a>";
  is $d<b>, 121, "\$d<b> = $d<b>";

}, "Initialize document";

#-------------------------------------------------------------------------------
subtest {

  my BSON::Document $d .= new;

  my $count = 0;
  for 'a' ... 'z' -> $c { $d{$c} = $count++; }
  
  is $d.elems, 26, "26 pairs";
  is $d{'d'}, 3, "\$d\{'d'\} = $d{'d'}";
  
  ok $d<q>:exists, '$d<q> exists';
  ok ! ($d<hsdgf>:exists), '$d<hsdgf> does not exist';

  is-deeply $d<a b>, ( 0, 1), 'Ask for two elements';
  is $d<d>:delete, 3, 'Deleted value is 3';
  is $d.elems, 25, "25 pairs left";

#`{{
  is $d<e>, 4, "Pre binding: \$d<e> = $d<e>";
  my $x = 10;
  $d<e> := $x;
  is $d<e>, 10, "Bound: \$d<e> = $d<e> == \$x = $x";
  $x = 11;
  is $d<e>, 11, "Bound: \$d<e> = $d<e> == \$x = $x";
}}

}, "Test document, associative";

#-------------------------------------------------------------------------------
subtest {

  my BSON::Document $d .= new: ('a' ... 'z') Z=> 120..145;
  
  is $d[0], 120, "\$d[0] = $d[0]";
  is $d[1], 121, "\$d[1] = $d[1]";
  
  $d[1] = 2000;
  is $d[1], 2000, "assign \$d[1] = $d[1]";
  is $d<b>, 2000, "assign \$<b> = \$d[1] = $d[1]";

  $d[1000] = 'text';
  is $d[26], 'text', "assign \$d[1000] = \$d[26] = '$d[26]'";
  is $d<key26>, 'text', "assign \$d<key26> = \$d[26] = '$d[26]'";

  is $d[2000], Any, "Any undefined field returns 'Any'";
  ok $d[26]:exists, '$d[26] exists';
  ok ! ($d[27]:exists), '$d[27] does not exist';

  is $d[25]:delete, 145, '$d[25] deleted was 145';
  ok $d[25]:exists, '$d[25] does still exist, shifted from \$d[26]';
  is $d[25], 'text', "\$d[25] = '$d[25]'";
  ok ! ($d[26]:exists), '$d[26] does not exist anymore';

#`{{
  is $d[4], 124, "Pre binding: \$d[4] = $d[4]";
  my $x = 10;
  $d[4] := $x;
  is $d[4], 10, "Bound: \$d[4] = $d[4] == \$x = $x";
  $x = 11;
  is $d[4], 11, "Bound: \$d[4] = $d[4] == \$x = $x";
}}

}, "Test document, positional";

#-------------------------------------------------------------------------------
subtest {

  my BSON::Document $d .= new: ('a' ... 'z') Z=> 120..145;
  
  is ($d.kv).elems, 2 * 26, '2 * 26 keys and values';
  is ($d.keys).elems, 26, '26 keys';
  is ($d.keys)[*-1], 'z', "Last key is 'z'";
  is ($d.values).elems, 26, '26 values';
  is ($d.values)[*-1], 145, "Last value is 145";

}, "Test document, other";

#-------------------------------------------------------------------------------
subtest {

  my BSON::Document $d .= new;
  $d<a> = 10;
  $d<b> = 11;
  $d<c> = BSON::Document.new: (p => 1, q => 2);
  $d<c><a> = 100;
  $d<c><b> = 110;

  is $d<c><b>, 110, "\$d<c><b> = $d<c><b>";
  is $d<c><p>, 1, "\$d<c><p> = $d<c><p>";

  is $d<c>[1], 2, "\$d<c>[1] = $d<c>[1]";
  is $d<c>[3], 110, "\$d<c>[3] = $d<c>[3]";

  is $d[2][2], 100, "\$d[2][2] = $d[2][2]";
  is $d[2][3], 110, "\$d[2][3] = $d[2][3]";

  is $d[1][0], 11, "\$d[1][0] = $d[1][0]";
  is $d[1][0][0], 11, "\$d[1][0][0] = $d[1][0][0]";

  try {
    say $d[1][2];
    CATCH {
      default {
        is ~$_,
           'Index out of range. Is: 2, should be in 0..0',
           '$d[1][2]: ' ~ $_;
      }
    }
  }

  try {
    is $d[2][5], Any, '$d[2][5]: not out of range but not defined';
    CATCH {
      default {
        is ~$_,
           'Index out of range. Is: 2, should be in 0..0',
           '$d[2][5]: ' ~ $_;
      }
    }
  }
  
}, "Document nesting";

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing();
exit(0);
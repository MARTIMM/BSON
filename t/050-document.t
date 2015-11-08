use v6;
use Test;
use BSON::Document;

#-------------------------------------------------------------------------------
subtest {

  my BSON::Document $d .= new;
  is $d.^name, 'Document', 'Isa ok';

  my $count = 0;
  for 'a' ... 'z' -> $c { $d{$c} = $count++; }
  
  is $d.elems, 26, "26 pairs";
  is $d{'d'}, 3, "\$d\{'d'\} = $d{'d'}";
  
  ok $d<q>:exists, '$d<q> exists';
  ok ! ($d<hsdgf>:exists), '$d<hsdgf> does not exist';

  is-deeply $d<a b>, ( 0, 1), 'Ask for two elements';
  is ($d.kv).elems, 2 * 26, '2 * 26 keys and values';
  is ($d.keys).elems, 26, '26 keys';

  is $d<d>:delete, 3, 'Deleted value is 3';
  is $d.elems, 25, "25 pairs left";

  my $x = 10;
  $d<e> := $x;
  is $d<e>, 10, "\$d<e> = $d<e> == $x";
  $x = 11;
  is $d<e>, 11, "\$d<e> = $d<e> == $x";

}, "Test document";

#-------------------------------------------------------------------------------
subtest {

  my BSON::Document $d .= new;
  $d<a> = 10;
  $d<b> = 11;
  $d<c> = BSON::Document.new;
  $d<c><a> = 100;
  $d<c><b> = 110;

  is $d<c><b>, 110, "\$d<c><b> = $d<c><b>";

}, "Document nesting";

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing();
exit(0);

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

}, "Test document";

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing();
exit(0);

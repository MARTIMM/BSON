use v6;
use Test;
#use NativeCall;

print "\n";

use BSON::Ordered;
use BSON::Document;

class A does BSON::Ordered { }
my A $a .= new;

$a<k1> = 10;
is $a<k1>, 10, 'assign to 1st level';
#note $a<k1>;

$a<k2><a> = 11;
is $a<k2><a>, 11, 'assign to 2nd level';

# Add a list to 2nd level
for ('a' ... 'f').reverse -> $c {
  $a<p>{$c} = $++;
}
is-deeply $a<p>.keys, ('a' ... 'f').reverse, '.keys()';
is-deeply $a<p>.values, (0...5), '.values()';
is-deeply $a<p>.pairs, (:0f, :1e, :2d, :3c, b => 4, a => 5), '.pairs()';
is-deeply $a<p>.kv, ('f', 0, 'e', 1, 'd', 2, 'c', 3, 'b', 4, 'a', 5), '.kv()';
is $a<p>.elems, 6, '.elems()';

# Add a Seq. Key 'j' gets an Ordered hash
$a<seq><b><c><d><e><f1><g><h><i><j><h><i><j> =
  (('a' ... 'z') Z=> 120..145).reverse;

#note 'j keys: ', $a<seq><b><c><d><e><f1><g><h><i><j><h><i><j>.document.keys;
#note 'j key arr: ', $a<seq><b><c><d><e><f1><g><h><i><j><h><i><j>.keys;

# Overwrite value of key 'f1'. Previous value is garbage collected.
# Keys array of 'e' doesn't have to change because 'f1' is not gone.
$a<seq><b><c><d><e><f1> = [^10];
is $a<seq><b><c><d><e><f1>[2], 2, 'item overwritten with array';

#note "\nDoc; ", '-' x 75, $a.raku, '-' x 80;

#-------------------------------------------------------------------------------
done-testing;
=finish

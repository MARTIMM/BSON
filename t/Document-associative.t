use v6;
use Test;
use NativeCall;

use BSON::Document;
use BSON::Ordered;

#-------------------------------------------------------------------------------
subtest "Document associative tests", {
  my BSON::Document $d;

  $d .= new;
  $d<a> = True;
  $d<c> = False;
  $d<b> = 11;
  $d<d> = 'dfg';
  is $d<d>, 'dfg', 'assign scalar to key';

  $d<e> = (:p<z>, :x(2e-2));
  is $d<e><p>, 'z', 'assign List of Pair to key';

  $d{'f'} = ⅓;
  is-approx $d<f>, ⅓, 'assign Rat to key -> convert to Num';

  my BSON::Document $d1 .= new: (:b<Foo>,);
  $d<xxxxx> = $d1;
  is $d<xxxxx><b>, 'Foo', 'assign BSON::Document';

  class A does BSON::Ordered { }
  my A $a .= new;
  $a<k1> = 10;
  $d<yyyyy> = $a;
  is $d<yyyyy><k1>, 10, 'assign BSON::Ordered';
  # cleanup
  $d<xxxxx>:delete;
  $d<yyyyy>:delete;

  $d<seq><b> = ('a' ... 'z') Z=> 120..145;
  is $d<seq><b><c>, 122, 'assign Seq to key';
  # cleanup
  $d<seq>:delete;
#note "\nDoc; ", '-' x 75, $d.raku, '-' x 80;

  is $d<b>:delete, 11, ':delete key';
  ok $d<b>:!exists, ':exists key';
  is-deeply $d.keys, <a c d e f>, '.keys()';

#  my $e = $d<e>:delete;
#  is-deeply $e, BSON::Document.new(( :p<z>, :x(0.02))), 'deleted key';

  is-deeply $d.values, ( True, False, 'dfg', BSON::Document.new(( :p<z>, :x(0.02))), ⅓.Num), '.values()';
  is $d.elems, 5, '.elems()';

  my $y = 12345;
  $d<y> := $y;
  is $d<y>, 12345, 'bind key';
  $y = 54321;
  is $d<y>, 54321, 'bound key is changed';

  lives-ok( {
      $d<document> = (
        insert => 'famous_people',
        documents => [(
            name => 'Larry',
            surname => 'Wall',
            languages => (
              Perl0 => 'introduced Perl to my officemates.',
              Perl1 => 'introduced Perl to the world',
              Perl2 => "introduced Henry Spencer's regular expression package.",
              Perl3 => 'introduced the ability to handle binary data.',
              Perl4 => 'introduced the first Camel book.',
              Perl5 => 'introduced everything else, including the ability to introduce everything else.',
              Perl6 => 'A perl changing perl event, Dec 12,2015',
              Raku => 'A name change, Oct 2019',
            ),
          ),
        ]
      );
    }, 'assign larger document with nested sub document and Array'
  );
#note "\nDoc; ", '-' x 75, $d.raku, '-' x 80;

  ok $d<empty-document-key> ~~ BSON::Document, 'associative auto create';
#note $d<c>.WHAT;
#note "\nDoc; ", '-' x 75, $d.raku, '-' x 80;
}

#-------------------------------------------------------------------------------
subtest 'Associative assign errors', {
  my BSON::Document $d .= new: ( :a(10), :b(11));

  throws-like {
    $d<c> = %( :c(11));
  }, X::BSON, 'Assign Hash error',
  :message(/:s Values cannot be Hash/);
}
#------------------------------------------------------------------------------
subtest "subdocs", {

  my BSON::Document $d .= new;

  $d<a> = 10;
  $d<b><a> = 11;
  $d<c><b><a> = 12;

#  diag $d.perl;

  ok $d<b> ~~ BSON::Document, 'subdoc at b';
  is $d<b><a>, 11, 'is 11';
  is $d<c><b><a>, 12, 'is 12';

  my Buf $b = $d.encode;
  $d .= new($b);
  ok $d<b> ~~ BSON::Document, 'subdoc at b after encode, decode';
  is $d<b><a>, 11, 'is 11 after encode, decode';
  is $d<c><b><a>, 12, 'is 12 after encode, decode';
}

#------------------------------------------------------------------------------
subtest "subdoc and array", {

  my BSON::Document $d .= new;

  $d<b><a> = [^5];

  is-deeply $d<b><a>, [^5], 'assign array with range ^5';

  my Buf $b = $d.encode;
  $d .= new($b);
  is-deeply $d<b><a>, [^5], 'range ^5 found after encode, decode';

  # try nesting with BSON::Document
  $d .= new;
  $d<a> = 10;
  $d<b> = 11;
  $d<c> = BSON::Document.new: ( p => 1, q => 2);
  $d<c><a> = 100;
  $d<c><b> = 110;
  $d<c><c> = [ 1, 2, ( :1p, :q([1,2,3])), 110];

  is $d<c><b>, 110, "\$d<c><b> = $d<c><b>";
  is $d<c><p>, 1, "\$d<c><p> = $d<c><p>";
  is-deeply $d<c><c>,
            [ 1, 2, BSON::Document.new(( p => 1, q => [1,2,3])), 110],
            'and a complex one';
}

#-------------------------------------------------------------------------------
subtest "Document nesting 2", {

  # Try nesting with k => v
  #
  my BSON::Document $d .= new;

  $d<abcdef> = a1 => 10, bb => 11;
  is $d<abcdef><a1>, 10, "sub document \$d<abcdef><a1> = $d<abcdef><a1>";

  $d<abcdef><b1> = q => 255;
  is $d<abcdef><b1><q>, 255,
     "sub document \$d<abcdef><b1><q> = $d<abcdef><b1><q>";

  $d .= new;
  $d<a> = v1 => (v2 => 'v3');
  is $d<a><v1><v2>, 'v3', "\$d<a><v1><v2> = $d<a><v1><v2>";
  $d<a><v1><w3> = 110;
  is $d<a><v1><w3>, 110, "\$d<a><v1><w3> = $d<a><v1><w3>";
}

#-------------------------------------------------------------------------------
# Test to see if no hangup takes place when making a special doc.
# On ubuntu docker (Gabor) this test seems to fail. On Travis(Ubuntu)
# or Fedora it works fine. So test only when on TRAVIS.

subtest "Big, wide and deep nesting", {

  # Keys must be sufficiently long and value complex enough to keep a
  # thread busy causing the process to runout of available threads
  # which are by default 16.
  my Num $count = 0.1e0;
  my BSON::Document $d .= new;

  for ('zxnbcvzbnxvc-aa', *.succ ... 'zxnbcvzbnxvc-bz') -> $char {
    $d{$char} = ($count += 2.44e0);
  }

  my BSON::Document $dsub .= new;
  for ('uqwteuyqwte-aa', *.succ ... 'uqwteuyqwte-bz') -> $char {
    $dsub{$char} = ($count += 2.1e0);
  }

  for ('uqwteuyqwte-da', *.succ ... 'uqwteuyqwte-dz') -> $char {
    $d<x1>{$char} = ($count += 2.1e0);
    $d<x2><x1>{$char} = $dsub.clone;
    $d<x2><x2><x3>{$char} = $dsub.clone;
  }

  for ('jhgsajhgasjdg-ca', *.succ ... 'jhgsajhgasjdg-cz') -> $char {
    $d{$char} = ($count -= 0.02e0);
  }

  for ('uqwteuyqwte-ea', *.succ ... 'uqwteuyqwte-ez') -> $char {
    $d<x3>{$char} = $dsub.clone;
    $d<x4><x1>{$char} = $dsub.clone;
    $d<x4><x2><x3>{$char} = $dsub.clone;
  }

#note "Encode big document";
  my Buf $b = $d.encode;
#note "Done encoding";
#note "Decode big document";
  $dsub .= new($b);
#note "Done decoding";

  is-deeply $dsub, $d, 'array nesting 1';
}


#------------------------------------------------------------------------------
subtest 'Array nesting', {
  my BSON::Document $d .= new: ( :a([1,2,3,[4,5,6,[7,8,9]]]) );
  my Buf $b = $d.encode;
  my BSON::Document $dsub .= new($b);
  is-deeply $dsub, $d, 'nested arrays';

  $d .= new: (
    :a([1,2,3,[:a<asd>,5,6,[(:x1<ghj>, :y<iuy>), :x2<ytr>]]])
  );
  $b = $d.encode;
  $dsub .= new($b);
  is-deeply $dsub, $d, 'nested arrays with pair and lists of pairs';

  $d .= new: ( :a([:a<bbb>,]) );
#note "\nDoc; ", '-' x 75, $d.raku, '-' x 80;
#  my Buf $b = $d.encode;
  $dsub .= new: ( :a([(:a<bbb>,),]) );
  is-deeply $dsub, $d, 'Array with a Pair converted to List of Pair';

}

#-------------------------------------------------------------------------------
done-testing;
=finish

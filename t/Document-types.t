use v6;
use Test;
use NativeCall;

use BSON::Document;

#-------------------------------------------------------------------------------
subtest "Document init input types", {
  my BSON::Document $d;

  $d .= new;
#  $d .= new(:a(10));           # hash -> error
#  $d .= new(:a(10), :11b);
#  $d .= new: :a(10);
#  $d .= new: ( :a({:b<def>, :c<abc>}));   # List of Pair with Hash

  $d .= new: ( :a(10), :11b);   # List of Pair
#  $d .= new: [ :a(10), :11b];

#  $d .= new: ( ( :a(10), :11b), :z<abc>); # List of Pair with Array
  $d .= new: ( :x( :a(10), :11b), :z<abc>); # List of Pair with Array

  $d .= new: (create => 'cl1');

  $d .= new: (
    insert => 'famous_people',
    documents => [
      BSON::Document.new((
        name => 'Larry',
        surname => 'Walll',
        languages => BSON::Document.new((
          Perl0 => 'introduced Perl to my officemates.',
          Perl1 => 'introduced Perl to the world',
          Perl2 => "introduced Henry Spencer's regular expression package.",
          Perl3 => 'introduced the ability to handle binary data.',
          Perl4 => 'introduced the first Camel book.',
          Perl5 => 'introduced everything else, including the ability to introduce everything else.',
          Perl6 => 'A perl changing perl event, Dec 12,2015'
        )),
      )),
    ]
  );

  note "\nDoc; ", $d.document;
  ok 1, '-';
}



#-------------------------------------------------------------------------------
done-testing;
=finish

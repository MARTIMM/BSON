use v6;
use Test;
use NativeCall;

use BSON::Document;
use Hash::Ordered;

#-------------------------------------------------------------------------------
subtest "Document init", {
  my BSON::Document $d;

  $d .= new: ( :a(10), :11b);   # List of Pair
  is $d<b>, 11, 'found Pair';

  $d .= new: ( :x( :a(10), :11b), :z<abc>); # List of Pair with Array
  is $d<x><b>, 11, 'found Pair in nested List';
#  note "\nDoc; ", $d.raku;


  lives-ok( {
      $d .= new: (
        insert => 'famous_people',
        documents => [
          BSON::Document.new((
            name => 'Larry',
            surname => 'Wall',
            languages => BSON::Document.new((
              Perl0 => 'introduced Perl to my officemates.',
              Perl1 => 'introduced Perl to the world',
              Perl2 => "introduced Henry Spencer's regular expression package.",
              Perl3 => 'introduced the ability to handle binary data.',
              Perl4 => 'introduced the first Camel book.',
              Perl5 => 'introduced everything else, including the ability to introduce everything else.',
              Perl6 => 'A perl changing perl event, Dec 12,2015',
              Raku => 'A name change, Oct 2019',
            )),
          )),
        ]
      );
    }, 'Larger document with nested sub document'
  );


  lives-ok( {
      $d .= new: (
        insert => 'famous_people',
        documents => [
          Hash::Ordered.new((
            name => 'Larry',
            surname => 'Wall',
            languages => Hash::Ordered.new((
              Perl0 => 'introduced Perl to my officemates.',
              Perl1 => 'introduced Perl to the world',
              Perl2 => "introduced Henry Spencer's regular expression package.",
              Perl3 => 'introduced the ability to handle binary data.',
              Perl4 => 'introduced the first Camel book.',
              Perl5 => 'introduced everything else, including the ability to introduce everything else.',
              Perl6 => 'A perl changing perl event, Dec 12,2015',
              Raku => 'A name change, Oct 2019',
            )),
          )),
        ]
      );
    }, 'Larger document now using Hash::Ordered'
  );
}

#-------------------------------------------------------------------------------
subtest 'Init errors', {
  my BSON::Document $d;

  throws-like {
    $d .= new( :q(20), :p<h>);
  }, X::BSON, 'top level Hash',
  :message(/:s Arguments cannot be Hash/);

  throws-like {
    $d .= new: ( :a({:b<def>, :c<abc>}));
  }, X::BSON, 'Nested Hash error',
  :message(/:s Values cannot be Hash/);

  throws-like {
    $d .= new: [ :a(10), :11b];
  }, X::BSON, 'Top level Array',
  :message(/:s type Array cannot be a top level/);

  throws-like {
    $d .= new: ( ( :a(10), :11b), :z<abc>);
  }, X::TypeCheck::Binding::Parameter, 'only List of Pair',
  :message(/:s expected Pair but got List/);
}

#-------------------------------------------------------------------------------
done-testing;
=finish

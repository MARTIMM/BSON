use v6;
use Test;
use NativeCall;

use BSON::Document;
use BSON::Ordered;

#`{{
my BSON::Document $d;
$d .= new: ('counter00', *.succ ... 'counter10') Z=> 0 xx 10;
$d .= new: (:a<b>);
$d.note;
done-testing;
=finish
}}

#-------------------------------------------------------------------------------
subtest "Document init", {
  my BSON::Document $d;

  subtest 'empty doc', {
    $d .= new;
    my Buf $b = $d.encode;
    is $b, Buf.new( 0x05, 0x00 xx 4), 'Empty doc encoded ok';
    $d .= new;
    $d.decode($b);
    is $d.elems, 0, "Zero elements/keys in decoded document";
  }

  subtest 'List of Pair test', {
    $d .= new: ( :a(10), :11b);
    is $d<b>, 11, '.new(List of Pair)';

    $d .= new: ( :x( :a(10), :11b), :z<abc>);
    is $d<x><b>, 11, '.new(nested List of Pair)';
#  note "\nDoc; ", $d.raku;
  }

  subtest 'BSON::Document and BSON::Ordered', {
    my BSON::Document $d0 .= new: (:b<Foo>);
    my BSON::Document $d1 .= new($d0);
    is $d1<b>, 'Foo', '.new(BSON::Document)';

    class A does BSON::Ordered { }
    my A $a .= new;
    $a<k1> = 10;
    $d1 .= new($a);
#    note "\nDoc; ", '-' x 75, $d1.raku, '-' x 80;
  }

  subtest 'Smart input', {
    given my BSON::Document $request .= new {
      .<find> = 'collection-name';
      .<filter> = :departement<administration>,;
      .<limit> = 10;
      .<readConcern> = :level<local>,;
    }
    is $request<limit>, 10, 'using "given { }" to add keys';
  }

  subtest 'Larger documents', {
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
      }, '.new(larger document with nested sub document and Array)'
    );

    is $d<documents>[0]<name>, 'Larry', '.new(document) orginal way';
    is $d<documents>[0]<languages><Raku>, 'A name change, Oct 2019',
      '.new(document) orginal way';

    $d .= new: (
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
  #note "\nDoc; ", '-' x 75, $d.raku, '-' x 80;

  #note "\nentry: ", $d<documents>[0]<languages>;


    is $d<documents>[0]<name>, 'Larry', '.new(document) nicer way';
    is $d<documents>[0]<languages><Raku>, 'A name change, Oct 2019',
      '.new(document) nicer way';
  }
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

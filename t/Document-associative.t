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

  $d<seq><b> = BSON::Document.new(('a' ... 'z') Z=> 120..145);
  is $d<seq><b><c>, 122, 'assign Seq to key';
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

#`{{
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
note "\nDoc; ", '-' x 75, $d.raku, '-' x 80;

#note "\nentry: ", $d<documents>[0]<languages>;

  is $d<documents>[0]<name>, 'Larry', '.new(document)';
  is $d<documents>[0]<languages><Raku>, 'A name change, Oct 2019',
    '.new(document)';
}}
}


#-------------------------------------------------------------------------------
subtest 'Associative assign errors', {
  my BSON::Document $d .= new: ( :a(10), :b(11));

  throws-like {
    $d<c> = %( :c(11));
  }, X::BSON, 'Assign Hash error',
  :message(/:s Values cannot be Hash/);
}

#-------------------------------------------------------------------------------
done-testing;
=finish

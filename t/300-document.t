use v6;
use Test;
use BSON::Document;

#-------------------------------------------------------------------------------
subtest "Empty document", {

  my BSON::Document $d .= new;
  is $d.^name, 'BSON::Document', 'Isa ok';
  my Buf $b = $d.encode;

  is $b, Buf.new( 0x05, 0x00 xx 4), 'Empty doc encoded ok';

  $d .= new;
  $d.decode($b);
  is $d.elems, 0, "Zero elements/keys in decoded document";
}

#-------------------------------------------------------------------------------
subtest "Initialize document", {

  # Init via Seq
  #
  my BSON::Document $d .= new: ('a' ... 'z') Z=> 120..145;

  is $d<a>, 120, "\$d<a> = $d<a>";
  is $d<b>, 121, "\$d<b> = $d<b>";
  is $d.elems, 26, "{$d.elems} elements";

  # Add one element, encode and decode using new(Buf)
  #
  $d<aaa> = 11;
  my Buf $b2 = $d.encode;
  my BSON::Document $d2 .= new($b2);
  is $d2.elems, 27, "{$d.elems} elements in decoded doc";
  is $d2<aaa>, 11, "Item is $d2<aaa>";

  # Init via list
  #
  $d .= new: (ppp => 100, qqq => ( d => 110, e => 120));
  is $d<ppp>, 100, "\$d<ppp> = $d<ppp>";
  is $d<qqq><d>, 110, "\$d<qqq><d> = $d<qqq><d>";

  # Init via hash inhibited
  throws-like { $d .= new: ppp => 100, qqq => ( d => 110, e => 120); },
    X::BSON, 'Cannot use hashes on init',
    :message(/:s Cannot use hash values on init/);
}

#-------------------------------------------------------------------------------
subtest "Ban the hash", {

  my BSON::Document $d .= new;
  throws-like {
      $d<q> = {a => 20};
      is $d<q><a>, 20, "Hash value $d<q><a>";
    }, X::BSON, 'Cannot use hashes when assigning',
    :message(/:s Cannot use hash values/);

  $d.accept-hash(:accept);
  $d<q> = {
    a => 120, b => 121, c => 122, d => 123, e => 124, f => 125, g => 126,
    h => 127, i => 128, j => 129, k => 130, l => 131, m => 132, n => 133,
    o => 134, p => 135, q => 136, r => 137, s => 138, t => 139, u => 140,
    v => 141, w => 142, x => 143, y => 144, z => 145
  };
  is $d<q><a>, 120, "Hash value $d<q><a>";
  my $x = $d<q>.keys.sort;
  nok $x eqv $d<q>.keys.List, 'Not same order';

  $d.autovivify(:on);

  $d<e><f><g> = {b => 30};
  is $d<e><f><g><b>, 30, "Autovivified hash value $d<e><f><g><b>";

  $d.autovivify(:!on);
  $d.accept-hash(:!accept);
}

#-------------------------------------------------------------------------------
subtest "Test document, associative", {

  my BSON::Document $d .= new;

  my $count = 0;
  for 'a' ... 'z' -> $c { $d{$c} = $count++; }

  is $d.elems, 26, "26 pairs";
  is $d{'d'}, 3, "\$d\{'d'\} = $d{'d'}";

  ok $d<a>:exists, 'First pair $d<a> exists';
  ok $d<q>:exists, '$d<q> exists';
  ok ! ($d<hsdgf>:exists), '$d<hsdgf> does not exist';

  is-deeply $d<a b>, ( 0, 1), 'Ask for two elements';
  is $d<d>:delete, 3, 'Deleted value is 3';
  is $d.elems, 25, "25 pairs left";

  throws-like {
      my $x = 10;
      $d<e> := $x;
    }, X::BSON, 'Cannot use binding',
    :message(/:s Cannot use binding/);
}

#-------------------------------------------------------------------------------
subtest "Test document, other", {

  my BSON::Document $d .= new: ('a' ... 'z') Z=> 120..145;

  is ($d.kv).elems, 2 * 26, '2 * 26 keys and values';
  is ($d.keys).elems, 26, '26 keys';
  is ($d.keys)[*-1], 'z', "Last key is 'z'";
  is ($d.values).elems, 26, '26 values';
  is ($d.values)[*-1], 145, "Last value is 145";
  is ($d.keys)[3], 'd', "4th key is 'd'";
  is ($d.values)[3], 123, '4th value is 123';
}

#-------------------------------------------------------------------------------
subtest "Simplified encode Rat test", {

  my BSON::Document $d .= new;

  throws-like {
    $d<a> = 3.5;
    $d.encode;
  }, X::BSON, 'Binary Rat not yet implemented',
  :message(/:s Not yet implemented/);

  $d .= new;
  $d.convert-rat(:accept);
  $d<a> = 3.5;
  my Buf $b = $d.encode;
  $d .= new($b);
  is $d<a>, 3.5, "Number is 3.5";
  ok $d<a> ~~ Num, "Number is of type Num";

  my Rat $n = 1.23847682734687263487623449827398724987234982374;
  ok $n.Num.Rat(0) != $n, "Rat number not of same precision as Num";

  $d .= new;
  throws-like {
    $d<a> = $n;
    $b = $d.encode;
  }, X::BSON, 'Rat can not be converted without losing pecision',
  :message(/:s without losing pecision/);

  $d .= new;
  $d.convert-rat( :accept, :accept-precision-loss ,:instance-only);
  $d<a> = $n;
  $b = $d.encode;
  $d .= new($b);
  ok $d<a>.Rat(0) != $n, "Number is not equal to $n";
  ok $d<a> ~~ Num, "Number is of type Num";
#  $d.convert-rat(:!accept);
}

#-------------------------------------------------------------------------------
subtest "Document desctructure tests", {

  # Create a document and bind it to a hash
  my %doc := BSON::Document.new: (
    a => 10,
    b => 11
  );

  # Create a sub with a sub-signature
  my $sub = sub ( % ( :$a, :$b, :$c=12)) {
    is $a, 10, 'a = 10';
    is $b, 11, 'b = 11';
    is $c, 12, 'c = 12';
  };

  # When calling, the Capture method is called to return a hash of the
  # documents contents
  $sub(%doc);
}

#-------------------------------------------------------------------------------
#`{{
subtest "reassignment test", {

  my BSON::Document $d .= new;
  $d<a> = 1;
  $d<b> = 2;
  ok $d<test-assign> ~~ BSON::TemporaryContainer, 'Temporary container';
  ok $d<test-assign2> ~~ BSON::TemporaryContainer, 'Temporary container';
  ok $d<test-assign3> ~~ BSON::TemporaryContainer, 'Temporary container';
  $d<test-assign> = 12345;
  $d<test-assign> = 54321;
  $d<test-assign2> = 890;
  diag $d.perl;

  my Buf $b = $d.encode;
  $d .= new($b);
  diag $d.perl;
  is $d<test-assign>, 54321, "Value is $d<test-assign>";
}
}}

#-------------------------------------------------------------------------------
#`{{
subtest "Slice assignment", {

  my BSON::Document $d .= new;
  $d<test-assign> = 12345;

$d.autovivify(:on);
  $d<firstname lastname> = <John Doe>;
  is $d<firstname>, 'John', "firstname set to $d<firstname>";
  is $d<lastname>, 'Doe', "lastname set to $d<lastname>";

  my %x = %(a => 10, b => 11, c => 12);
  my @keys = <a c>;
  $d{@keys} = %x{@keys};

  is $d<a>, 10, 'Key a set';
  is $d<b>, Any, 'Key b not set';
  is $d<c>, 12, 'Key c set';

  $d<p q r> = ('a', 'b', (a => 11));
  diag "$?LINE, $d.perl()";

  my Buf $b = $d.encode;
  note "$?LINE, ", $b;
  diag "$?LINE, $d.new($b).perl()";
$d.autovivify(:!on);
}
}}

#-------------------------------------------------------------------------------
subtest "Exception tests", {

  # Hash tests done above
  # Bind keys done above

  throws-like {
      my BSON::Document $d .= new;
      $d<js> = BSON::Javascript.new(:javascript(''));
      $d.encode;
    }, X::BSON, 'empty javascript',
    :message(/:s cannot process empty javascript code/);

  throws-like {
      my BSON::Document $d .= new;
      $d<int1> = 1762534762537612763576215376534;
      $d.encode;
    }, X::BSON, 'too large',
    :message(/:s Number too large/);

  throws-like {
      my BSON::Document $d .= new;
      $d<int2> = -1762534762537612763576215376534;
      $d.encode;
    }, X::BSON, 'too small',
    :message(/:s Number too small/);

  throws-like {
      my BSON::Document $d .= new;
      $d{"Double\0test"} = 1.2.Num;
      $d.encode;
    }, X::BSON, '0x00 in string',
    :message(/:s Forbidden 0x00 sequence in/);

  throws-like {
      my BSON::Document $d .= new;
      $d<test> = 1.2.Num;
      my Buf $b = $d.encode;

      # Now use encoded buffer and take a slice from it rendering it currupt.
      my BSON::Document $d2 .= new;
      $d2.decode(Buf.new($b[0 ..^ ($b.elems - 4)]));
    }, X::BSON, 'not enough',
    :message(/:s Not enough characters left/);

  throws-like {
      my $b = Buf.new(
        0x0B, 0x00, 0x00, 0x00,           # 11 bytes
          BSON::C-INT32,                  # 0x10
          0x62,                           # 'b' note missing tailing char
          0x01, 0x01, 0x00, 0x00,         # integer
        0x00
      );

      my BSON::Document $d .= new($b);
    }, X::BSON, 'size does not match',
    :message(/:s Size of document\(.*\) does not match/);

  throws-like {
      class A { }
      my A $a .= new;

      my BSON::Document $d .= new;
      $d{"A"} = $a;
      $d.encode;
    }, X::BSON, 'Not a BSON type',
    :message(/'encode() on A<' \d* '>, error: Not yet implemented'/);

  throws-like {
      my $b = Buf.new(
        0x0B, 0x00, 0x00, 0x00,           # 11 bytes
          0xa0,                           # Unimplemented BSON code
          0x62, 0x00,                     # 'b'
          0x01, 0x01, 0x00, 0x00,         # integer
        0x00
      );

      my BSON::Document $d .= new($b);
    },
    X::BSON, 'type is not implemented',
    :message(/ 'decode() on 160, error: BSON code \'0xa0\' not implemented'/);

  throws-like {
      my $b = Buf.new(
        0x0F, 0x00, 0x00, 0x00,           # 15 bytes
          BSON::C-STRING,                 # 0x02
          0x62, 0x00,                     # 'b'
          0x03, 0x00, 0x00, 0x00,         # 3 bytes total
          0x61, 0x62, 0x63,               # Missing 0x00 at the end
        0x00
      );

      my BSON::Document $d .= new($b);
    }, X::BSON, 'Missing trailing 0x00',
    :message(/:s Missing trailing 0x00/);
}

#-------------------------------------------------------------------------------
# Cleanup
done-testing;

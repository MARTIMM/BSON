use v6.d;

#TODO There are some *-native() and *-emulated() subs kept for later benchmarks
# when perl evolves.

#-------------------------------------------------------------------------------
use NativeCall;
#use trace;

use BSON;
use BSON::ObjectId;
use BSON::Regex;
use BSON::Javascript;
use BSON::Binary;
use BSON::Decimal128;
use BSON::Encode;
use BSON::Decode;

use Hash::Ordered;
use Method::Also;

#-------------------------------------------------------------------------------
unit class BSON::Document:auth<github:MARTIMM>:ver<0.2.0>;
also does Associative;
#also does Hash::Ordered;
#also does BSON::Encode;
#also does BSON::Decode;

#-------------------------------------------------------------------------------
has %.document is Hash::Ordered;    # handles <elems kv pairs keys>;
has BSON::Encode $!encode-object;
has BSON::Decode $!decode-object;

#-------------------------------------------------------------------------------
# Associative role methods
#
# We only need to handle top level entries. deeper levels
# are processed by Hash::Ordered
#-------------------------------------------------------------------------------
# Example: note $d<x>;
method AT-KEY ( Str $key --> Any ) {
note "AT-KEY $key";
  %!document{$key} = Hash::Ordered.new unless %!document{$key}.defined;
  return-rw %!document{$key};
}

#-------------------------------------------------------------------------------
# Example: $d<x> = 'y';
multi method ASSIGN-KEY ( Str:D $key, Seq:D $new --> Nil ) {
note "ASSIGN-KEY Seq $key, ", $new.WHAT;
  self.ASSIGN-KEY( $key, $new.List);
}

multi method ASSIGN-KEY ( Str:D $key, Any:D $new --> Nil ) {
note "ASSIGN-KEY Any $key, ", $new.WHAT;
  %!document{$key} = walk-tree( Hash::Ordered.new, $new);
}

#-------------------------------------------------------------------------------
# Example: $d<y> := $y;
method BIND-KEY ( Str $key, \new ) {
  %!document{$key} := new;
}

#-------------------------------------------------------------------------------
# Example: $d<x>:exists;
method EXISTS-KEY ( Str $key --> Bool ) {
  %!document{$key}:exists
}

#-------------------------------------------------------------------------------
# Example: $d<x>:delete;
method DELETE-KEY ( Str $key --> Any ) {
  %!document{$key}:delete
}

#-------------------------------------------------------------------------------
method elems ( --> Int ) {
  %!document.elems
#    @!keys.elems;
}

#-------------------------------------------------------------------------------
method kv ( --> List ) {
  (|%!document.kv)
#`{{
  my @kv-list;
  loop ( my $i = 0; $i < @!keys.elems; $i++) {
    @kv-list.push( @!keys[$i], @!values[$i]);
  }

  @kv-list;
}}
}

#-------------------------------------------------------------------------------
method pairs ( --> List ) {

#while my $cf = callframe($++) {
#  note $cf.gist;
#}

  note self.defined;
  (|%!document.pairs)
#`{{
  my @pair-list;
  loop ( my $i = 0; $i < @!keys.elems; $i++) {
    @pair-list.push: ( @!keys[$i] => @!values[$i]);
  }

  @pair-list;
}}
}

#-------------------------------------------------------------------------------
method keys ( --> List ) {
  %!document.keys.List
}

#-------------------------------------------------------------------------------
method values ( --> List ) {
  %!document.values.List
}


#-------------------------------------------------------------------------------
# Initializing
#---------------------------------------------------------------------------------
# - %options must be empty. If not, it is a Hash -> illegal
# - @arguments can be;
#   - List of Pair
#   - List of BSON::Document
#   - List of Hash::Ordered
#   - An Array with items
#   - A Buf
#   - A CArray[byte]
method new( **@arguments, *%options ) {

  die X::BSON.new(
    :operation("new: Hash %options.gist()"), :type<Hash>,
    :error("Arguments cannot be Hash")
  ) if %options.elems;

  self.bless(:@arguments);
}

#-------------------------------------------------------------------------------
submethod BUILD ( :@arguments ) {

  $!encode-object .= new;
  $!decode-object .= new;
  %!document = Hash::Ordered.new;

  # every entry in bson must have a name so Array can not be a top level item
  # all top level items are Pair or binary.
  for @arguments -> $item {
#note 'new item: ', $item.WHAT;

    given $item {
      when Pair {
        %!document{$item.key} = walk-tree( %!document, $item.value);
      }

      when Array {
        die X::BSON.new(
          :operation("new: type Array cannot be a top level object"),
          :type($item.^name), :error("Unsupported type")
        );
      }

      when List {
        %!document = walk-tree( Hash::Ordered.new, $item);
      }

      when BSON::Document {
        %!document = $item.document;
      }

      when Hash::Ordered {
        %!document = |walk-tree( Hash::Ordered.new, $item);
      }

      when Buf {
        %!document = self.decode($item);
      }

      when CArray[byte] {
      }

      default {
        die X::BSON.new(
          :operation("new: type {$item.^name} not supported"),
          :type($item.^name), :error("Unsupported type")
        );
      }
    }
  }
#note 'new %!document: ', %!document;
}

#-------------------------------------------------------------------------------
sub walk-tree ( %doc, $item --> Any ) {

  given $item {
    when !.defined {
      die X::BSON.new(
        :operation("List $item"), :type<Hash>,
        :error("Values cannot be undefined")
      );
    }

    when Seq {
      for @$item -> Pair $i {
note "Seq: $i.key(), $i.value()";
        %doc{$i.key} = walk-tree( Hash::Ordered.new, $i.value);
      }

note "Seq: ", %doc.WHAT;
      return %doc;
    }

    when Array {
      my Array $a = [];
      for @$item -> $i {
        $a.push: walk-tree( Hash::Ordered.new, $i);
      }

      return $a;
    }

    when Pair {
note "wt1 Pair: $item.key(), $item.value()";
      %doc{$item.key} = walk-tree( Hash::Ordered.new, $item.value);
      return %doc;
    }

    # A List should only contain Pair and is inserted in doc as kv pairs
    when List {
      for @$item -> Pair $i {
        %doc{$i.key} = walk-tree( Hash::Ordered.new, $i.value);
      }

      return %doc;
    }

    when BSON::Document {
      return $item.document;
    }

    when Hash::Ordered {
note "wt2 HO: $item.keys(), $item.values()";
      for $item.keys -> $k {
        %doc{$k} = walk-tree( Hash::Ordered.new, $item{$k});
      }
      return %doc;
    }

    when Hash {
      die X::BSON.new(
        :operation("List $item"), :type<Hash>,
        :error("Values cannot be Hash")
      );
    }

    default {
      return $item ~~ Rat ?? $item.Num !! $item;
    }
  }
}


#-------------------------------------------------------------------------------
method raku ( Int :$indent is copy = 0 --> Str ) is also<perl> {
  my $s = [~] "\n", '  ' x $indent, "BSON::Document.new: (\n";
  for %!document.keys -> $key {
    $s ~= [~] '  ' x $indent + 1, $key, ' => ',
          show-tree( %!document{$key}, $indent + 1), "\n";
  }
  $s ~= [~] '  ' x $indent, ");\n";

  $s
}

#-------------------------------------------------------------------------------
sub show-tree ( $item, $indent is copy --> Str ) {

  my Str $s = '';
#note $item, ', ', $item.^name ~~ 'Hash::Ordered' ?? 'HO' !! $item.WHAT;

  given $item {
    when Array {
      $s = "[\n";
      $indent++;
      for @$item -> $i {
        $s ~= [~] '  ' x $indent, show-tree( $i, $indent), "\n";
      }
      $indent--;
      $s ~= [~] '  ' x $indent, "],";
    }

    when List {
      $s = "(\n";
      $indent++;
      for @$item -> $i {
        $s ~= [~] '  ' x $indent, $i.key, ' => ',
              show-tree( $i.value, $indent), "\n";
      }
      $indent--;
      $s ~= [~] '  ' x $indent, "),";
    }

    when Hash::Ordered {
      $s = [~] "BSON::Document.new((\n";
      $indent++;
      for $item.keys -> $key {
        $s ~= [~] '  ' x $indent, $key, ' => ',
              show-tree( $item{$key}, $indent), "\n";
      }
      $indent--;
      $s ~= [~] '  ' x $indent, ")),";
    }

    when Str {
      $s = [~] "'", $item, "',";
    }

    default {
      $s = [~] $item, ",";
    }
  }

  $s
}

#-------------------------------------------------------------------------------
method decode ( Buf $b --> Any ) {
  $!decode-object.decode($b);
}

#-------------------------------------------------------------------------------
method encode ( --> Buf ) {
  $!encode-object.encode(%!document);
}







=finish










#---------------------------------------------------------------------------------
subset Index of Int where $_ >= 0;

#---------------------------------------------------------------------------------
#has Str @!keys;
#has @!values;

has Buf $!encoded-document;
has Buf @!encoded-entries;
has Index $!index = 0;

has %!promises is Hash::Ordered;

# Keep this value global to the class. Any old or new object has the same
# settings. With these flags also the same set as an attribute. Therefore
# we can keep these also to 'instance only'.
# Test is like; $!autovivify || $autovivify
#  my Bool $autovivify = False;
#  my Bool $accept-hash = False;
my Bool $convert-rat = False;
my Bool $accept-loss = False;

#  has Bool $!autovivify = False;
#  has Bool $!accept-hash = False;
has Bool $!convert-rat = False;
#  has Bool $!accept-loss = False;

has %.document is Hash::Ordered;# handles <elems kv pairs keys>;


#`{{
#-------------------------------------------------------------------------------
sub circumfix:('<','>')($key) is export {
  note "start", $key, "end"
}
}}

#-------------------------------------------------------------------------------
# Make new document and initialize with a list of pairs
#TODO better type checking:  List $pairs where all($_) ~~ Pair
#TODO better API
multi method new ( List $pairs ) {
note 'new List: ', $pairs;
  self.bless(:$pairs);
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Make new document and initialize with a pair
# No default value! is handled by new() above
multi method new ( Pair $p ) {
note 'new Pair';
  my List $pairs = $p.List;
  self.bless(:$pairs);
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Make new document and initialize with a pair
# No default value! is handled by new() above
multi method new ( Hash::Ordered $ho ) {
note 'new Ordered';
  self.bless(:$ho);
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
multi method new ( Hash $p ) {
note 'new Hash';
  die X::BSON.new(
    :operation("new: Hash $p.gist()"), :type<Hash>,
    :error("Arguments cannot be Hash")
  );
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Make new document and initialize with a sequence of pairs
# No default value! is handled by new() above
multi method new ( Seq $p ) {
note 'new Seq';
  my List $pairs = $p.List;
  self.bless(:$pairs);
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Make new document and initialize with a byte array. This will call
# decode from BUILD( Buf :$buf! ).
multi method new ( Buf $b ) {
note 'new Buf';
  self.bless(:buf($b));
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Make new document and initialize with a native byte array. This will call
# decode from BUILD( CArray[byte] :$bytes! ).
multi method new ( CArray[byte] $b ) {
note 'new CArray';
  self.bless(:bytes($b));
}

#`{{
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Other cases. No arguments will init empty document. Named values
# are associative thingies in a Capture and therefore throw an exception.
multi method new ( |capture ) {

  if capture.keys {
    die X::BSON.new(
      :operation("new: " ~ capture.gist), :type<capture>,
      :error(
        "Cannot use hash values on init.\n",
#          "Set accept-hash and use assignments later"
      )
    );
  }

  self.bless( :pairs(List.new()), :h({}));
}
}}

#-------------------------------------------------------------------------------
multi submethod BUILD ( Hash::Ordered :$ho ) {
note 'BUILD ordered: ', $ho;

  self!initialize;

  walk-tree( %!document, $ho);
}

#-------------------------------------------------------------------------------
multi submethod BUILD ( List :$pairs! ) {
#note "build pairs: $pairs";
note 'BUILD List';

  self!initialize;


  # self{x} = y will end up at ASSIGN-KEY
  for @$pairs -> $pair {
#note "P: ", $pair.perl;
    walk-tree( %!document, $pair);
#`{{
    die X::BSON.new(
      :operation("new: List $pairs.gist()"), :type<List>,
      :error("Pair not defined")
    ) unless ?$pair;
    die X::BSON.new(
      :operation("new: List $pairs.gist()"), :type<List>,
      :error("Key of pair not defined or empty")
    ) unless ?$pair.key;

    die X::BSON.new(
      :operation("new: List $pairs.gist()"), :type<List>,
      :error("Value of pair not defined")
    ) unless $pair.value.defined;
}}

#note "V: $pair.key(), ", $pair.value.WHAT;
#`{{
    given $pair.value {
      when Hash {
      }

      when List {

        %!document{$pair.key} = %();
        for |$pair.value -> Pair $v {
note "LOP: $v.key(), $v.value()";
          %!document{$pair.key}{$v.key} = $v.value;
        }
      }

#        when Hash {
#        }

      default {
        %!document{$pair.key} = $pair.value;
      }
    }
}}
  }
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
multi submethod BUILD ( Buf :$buf! ) {
note 'BUILD buf';

  self!initialize;

  # Decode buffer data
  self.decode($buf);
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Make new document and initialize with a pair
# No default value! is handled by new() above
multi submethod BUILD ( CArray[byte] :$bytes! ) {

  self!initialize;

  my Buf $length-field .= new($bytes[0..3]);
#    my Int $doc-size = decode-int32( $length-field, 0);
  my Int $doc-size = $length-field.read-uint32( 0, LittleEndian);

  # And get all bytes into the Buf and convert it back to a BSON document
  self.decode(Buf.new( $bytes[0..($doc-size-1)] ));
}

#-------------------------------------------------------------------------------
sub walk-tree ( %doc, Any $item ) {
note 'wt0: ', $item//'-';
  given $item {
    when !.defined {

    }

    when Pair {
note "wt1: $item.key(), $item.value()";
      given $item.value {
        when List {
          %doc{$item.key} = %();# is Hash::Ordered;
          for |$item.value -> $v {
            walk-tree( %doc{$item.key}, $v);
          }
        }

  #          when Hash::Ordered {
  #          }

  #          when BSON::Document {
  #          }

        when Hash {
          die X::BSON.new(
            :operation("new: List $item.gist()"), :type<Hash>,
            :error("Values cannot be a Hash")
          );
        }

        default {
          %doc{$item.key} = $item.value;
        }
      }
    }

    when List {
note "wt2: $item";
      my BSON::Document $d;
      %doc{$item.key} = [];
      for |$item -> $i {
        $d.new($i);
        %doc{$item.key}.push: $d.document;
      }
    }

    when Hash::Ordered {
note "wt3: $item";
      my BSON::Document $d;
      my %m is Hash::Ordered;
      %doc{$item.key} := %m;
      for $item.keys -> $k {
        $d.new($item{$k});
        %doc{$item.key}{$k} = $d.document;
      }
    }

    when Hash {
      die X::BSON.new(
        :operation("new: List $item.gist()"), :type<Hash>,
        :error("Values cannot be a Hash")
      );
    }
  }
}

#-------------------------------------------------------------------------------
method !initialize ( ) {

#    @!keys = ();
#    @!values = ();
  %!document = %();

  $!encoded-document = Buf.new();
  @!encoded-entries = ();

  %!promises = ();
}

#-------------------------------------------------------------------------------
method perl ( Int $indent = 0, Bool :$skip-indent = False --> Str ) {
  $indent = 0 if $indent < 0;

  my Str $perl = '';
  $perl ~= '  ' x $indent unless $skip-indent;
  $perl ~= "BSON::Document.new((\n";
  $perl ~= self!str-pairs( $indent + 1, self.pairs);
  $perl ~= ('  ' x $indent) ~ "))";
  $perl ~= ($indent == 0 ?? '' !! ',') ~ "\n";
  return $perl;
}

#-------------------------------------------------------------------------------
method !str-pairs ( Int $indent, List $items --> Str ) {
  my Str $perl = '';
  for @$items -> $item {
    my $key;
    my $value;

    if $item.^can('key') {
      $key = $item.key;
      $value = $item.value // 'Nil';
      $perl ~= '  ' x $indent ~ "$key => ";
    }

    else {
      $value = $item // 'Nil';
    }

#note "v: $value";
    given $value {
      when $value ~~ BSON::Document {
        $perl ~= '  ' x $indent unless $key.defined;
        $perl ~= $value.perl( $indent, :skip-indent($key.defined));
      }

      when $value ~~ Array {
        $perl ~= '  ' x $indent unless $key.defined;
        $perl ~= "[\n";
        $perl ~= self!str-pairs( $indent + 1, @$value);
        $perl ~= '  ' x $indent ~ "],\n";
      }

      when $value ~~ List {
        $perl ~= '  ' x $indent unless $key.defined;
        $perl ~= "(\n";
        $perl ~= self!str-pairs( $indent + 1, @$value);
        $perl ~= '  ' x $indent ~ "),\n";
      }

#TODO check if this can be removed in later perl versions
      when $value ~~ Buf {
        $perl ~= '  ' x $indent unless $key.defined;
        $perl ~= $value.perl ~ ",\n";
      }

#          when $value.^name eq 'BSON::ObjectId' {
#            $perl ~= '  ' x $indent unless $key.defined;
#            $perl ~= $value.perl,\n";
#          }

      when $value.^name eq 'BSON::Binary' {
        $perl ~= '  ' x $indent unless $key.defined;
        $perl ~= $value.perl($indent) ~ ",\n";
      }

      when $value.^name eq 'BSON::Regex' {
        $perl ~= '  ' x $indent unless $key.defined;
        $perl ~= $value.perl($indent) ~ ",\n";
      }

      when $value.^name eq 'BSON::Javascript' {
        $perl ~= '  ' x $indent unless $key.defined;
        $perl ~= $value.perl($indent) ~ ",\n";
      }

      when ?$value.^can('perl') {
        $perl ~= '  ' x $indent unless $key.defined;
        $perl ~= $value.perl ~ ",\n";
      }

      default {
        $perl ~= '  ' x $indent unless $key.defined;
        $perl ~= "$value,\n";
      }
    }
  }

  return $perl;
}

#-------------------------------------------------------------------------------
submethod Str ( --> Str ) {
  self.perl;
}

#-------------------------------------------------------------------------------
#TODO instance-only doesn't have much use. When True one still cannot
# assign this '$d<a><b><c> = 56;' because the flagis not inherited by the
# created document 'b' and therefore will not create 'c'.

method autovivify
  ( Bool :$on = True, Bool :$instance-only = False )
  is DEPRECATED("list of Pair of Hash::Ordered")
{
#    $!autovivify = $on;
#    $autovivify = $on && !$instance-only;
}

#-------------------------------------------------------------------------------
method accept-hash
  ( Bool :$accept = True, Bool :$instance-only = False )
  is DEPRECATED("list of Pair of Hash::Ordered")
{
#    $!accept-hash = $accept;
#    $accept-hash = $accept && !$instance-only;
}

#-------------------------------------------------------------------------------
method convert-rat (
  Bool $accept = True,
  Bool :$accept-precision-loss = False,
  Bool :$instance-only = False
) {

  $!convert-rat = $accept;
  $convert-rat = $accept && !$instance-only;
  $accept-loss = $accept-precision-loss;
}

#`{{
#-------------------------------------------------------------------------------
method find-key ( Str:D $key --> Int ) {

  for ^@!keys.elems -> $i {
    return $i if @!keys[$i] eq $key
  }

  Int
}
}}

##`{{
#-------------------------------------------------------------------------------
# Associative role methods
#-------------------------------------------------------------------------------
method AT-KEY ( Str $key --> Any ) {
note "At-key: $key, {%!document{$key}//'-'}, ", %!document{$key}.WHAT;

  if %!document{$key}.defined {
    %!document{$key}
  }

  else {
    my %h is Hash::Ordered = %();
    %!document{$key} = %h;
  }
#`{{
  my $value;
  my Int $idx = self.find-key($key);

  if $idx.defined {
#note "return @!values[$idx]";
    return-rw @!values[$idx];
  }

  # No key found so its undefined, check if we must make a new entry
  elsif $!autovivify || $autovivify {
#note 'autovivify';
    $value = BSON::Document.new;
    self{$key} = $value;
    return-rw self{$key};
#note "At-key($?LINE): $key => ", $value.WHAT;
  }

  else {
#note 'return temporary container';
    return Any;

    # next gives a proper version but leaves an Nil value when only reading
    # that should be removed when only reading instead of asssigning.
#      self{$key} = TemporaryContainer;
    $idx = self.find-key($key);

    return-rw @!values[$idx];
  }
}}
}

#-------------------------------------------------------------------------------
# Enable BSON::Document to be destructured.
method Capture ( BSON::Document:D: --> Capture ) {
note "Capture";
  (%!document.keys Z=> %!document.keys.values).Capture
#    return (self.keys Z=> self.values).Capture;
}

#-------------------------------------------------------------------------------
method EXISTS-KEY ( Str $key --> Bool ) {
note "EXISTS-KEY: $key";
  %!document{$key}:exists
#    self.find-key($key).defined;
}

#-------------------------------------------------------------------------------
method DELETE-KEY ( Str $key --> Any ) {
note "DELETE-KEY: $key";
  %!document{$key}:delete
#`{{
  my $value;
  if (my Int $idx = self.find-key($key)).defined {
    $value = @!values.splice( $idx, 1);
    @!keys.splice( $idx, 1);
    @!encoded-entries.splice( $idx, 1) if @!encoded-entries.elems;
  }

  $value;
}}
}

#-------------------------------------------------------------------------------
# All assignments of values which become or already are BSON::Documents
# will not be encoded in parallel.
#multi method ASSIGN-KEY ( Str:D $key, BSON::Document:D $new --> Nil ) {
method ASSIGN-KEY ( Str:D $key, Any:D $new --> Nil ) {
note "ASSIGN-KEY: $key";
  die X::BSON.new(
    :operation("assign: Hash $new.gist()"), :type<Hash>,
    :error("Cannot use hashes when assigning'")
  ) if $new ~~ Hash;

  %!document{$key} = Nil;
  walk-tree( %!document{$key}, $new);
#`{{
#note "Asign-key($?LINE): $key => ", $new.WHAT;

  my Str $k = $key;
  my BSON::Document $v = $new;

  my Int $idx = self.find-key($k);
  $idx //= @!keys.elems;
  @!keys[$idx] = $k;
  @!values[$idx] = $v;
}}
}

#`{{
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
multi method ASSIGN-KEY ( Str:D $key, List:D $new --> Nil ) {

#note "$*THREAD.id(), List, Asign-key($?LINE): $key => ", $new.WHAT, ', ', $new[0].WHAT;
  my BSON::Document $v .= new;
  for @$new -> $pair {
    if $pair ~~ Pair {
      $v{$pair.key} = $pair.value;
    }

    else {
      die X::BSON.new(
        :operation("\$d<$key> = ({$pair.perl}, ...)"), :type<List>,
        :error("Can only use lists of Pair")
      );
    }
  }

  my Str $k = $key;
  my Int $idx = self.find-key($k);
  $idx //= @!keys.elems;
  @!keys[$idx] = $k;
  @!values[$idx] = $v;
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
multi method ASSIGN-KEY ( Str:D $key, Pair $new --> Nil ) {

#note "$*THREAD.id(), Pair, Asign-key($?LINE): $key => ", $new.WHAT;

  my Str $k = $key;
  my BSON::Document $v .= new;

  $v{$new.key} = $new.value;

  my Int $idx = self.find-key($k);
  $idx //= @!keys.elems;
  @!keys[$idx] = $k;
  @!values[$idx] = $v;
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Hashes and sequences are reprocessed as lists
multi method ASSIGN-KEY ( Str:D $key, Hash $new --> Nil ) {

#note "$*THREAD.id(), Hash, Asign-key($?LINE): $key => ", $new;

  unless $!accept-hash || $accept-hash {
    die X::BSON.new(
      :operation("\$d<$key> = {$new.perl}"), :type<Hash>,
      :error("Cannot use hash values.\nSet accept-hash if you really want to")
    );
  }

  self.ASSIGN-KEY( $key, $new.List);
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
multi method ASSIGN-KEY ( Str:D $key, Seq $new --> Nil ) {

#note "$*THREAD.id(), Seq, Asign-key($?LINE): $key => ", $new;
  self.ASSIGN-KEY( $key, $new.List);
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Array will become a document but is not nested into subdocs and can
# be calculated in parallel.
#
multi method ASSIGN-KEY ( Str:D $key, Array:D $new --> Nil ) {

#TODO Test pushes and pops

#note "$*THREAD.id(), Array, Asign-key($?LINE): $key => ", $new;

  my Str $k = $key;
  my Array $v = $new;

  my Int $idx = self.find-key($k);
  $idx //= @!keys.elems;
  @!keys[$idx] = $k;
  @!values[$idx] = $v;
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# All other values are calculated in parallel
#
multi method ASSIGN-KEY ( Str:D $key, Any $new --> Nil ) {

#note "$*THREAD.id(), Any, Asign-key($?LINE): $key => ", $new.WHAT;

  my Str $k = $key;
  my $v = $new;
  my Int $idx = self.find-key($k);
  $idx //= @!keys.elems;
  @!keys[$idx] = $k;
  @!values[$idx] = $v;
}
}}

#-------------------------------------------------------------------------------
# Cannot use binding because when value changes this object cannot know that
# the location is changed. This is nessesary to encode the key, value pair.
#
method BIND-KEY ( Str $key, \new ) {
note "BIND-KEY: $key";
  %!document{$key} := new;
#`{{
  die X::BSON.new(
    :operation("\$d<$key> := {new}"), :type<any>,
    :error("Cannot use binding")
  );
}}
}
#}}

#-------------------------------------------------------------------------------
# Must be defined because of Associative sources of of()
#-------------------------------------------------------------------------------
method of ( ) {
  BSON::Document;
}

#`{{
#-------------------------------------------------------------------------------
method CALL-ME ( |capture ) {
  die "Call me capture: ", capture.perl;
}
}}
#-------------------------------------------------------------------------------
# And some extra methods
#-------------------------------------------------------------------------------
method elems ( --> Int ) {
  %!document.elems
#    @!keys.elems;
}

#-------------------------------------------------------------------------------
method kv ( --> List ) {
  (|%!document.kv)
#`{{
  my @kv-list;
  loop ( my $i = 0; $i < @!keys.elems; $i++) {
    @kv-list.push( @!keys[$i], @!values[$i]);
  }

  @kv-list;
}}
}

#-------------------------------------------------------------------------------
method pairs ( --> List ) {

#while my $cf = callframe($++) {
#  note $cf.gist;
#}

  note self.defined;
  (|%!document.pairs)
#`{{
  my @pair-list;
  loop ( my $i = 0; $i < @!keys.elems; $i++) {
    @pair-list.push: ( @!keys[$i] => @!values[$i]);
  }

  @pair-list;
}}
}

#-------------------------------------------------------------------------------
method keys ( --> List ) {
  |%!document.keys
#    @!keys.list;
}

#-------------------------------------------------------------------------------
method values ( --> List ) {
  |%!document.values
#    @!values.list;
}

#`{{
#-------------------------------------------------------------------------------
#TODO very slow method
method modify-array ( Str $key, Str $operation, $data --> List ) {

  my Int $idx = self.find-key($key);
  if self{$key}:exists and self{$key} ~~ Array and self{$key}.can($operation) {

    my $array = self{$key};
    $array."$operation"($data);
    self{$key} = $array;
  }
}
}}

#-------------------------------------------------------------------------------
# Encoding document
#-------------------------------------------------------------------------------
# Called from user to get a complete encoded document or by a request
# from an encoding Document to encode a subdocument or array.
#  method encode ( $document: --> Buf ) {
method encode ( --> Buf ) {

  # encode all in parallel except for Arrays and Documents. This level must
  # be done first.

  for %!document.keys -> $k {
    my $v = %!document{$k};
#note "E0: $k, $v";
    next if $v ~~ any(Array|BSON::Document|Hash::Ordered);

    %!promises{$k} = Promise.start( {
        self!encode-element: ($k => $v);
      }
    );
  }
#`{{
  for ^@!keys.elems -> $idx {
    my $v = @!values[$idx];
    next if $v ~~ any(Array|BSON::Document);

    my $k = @!keys[$idx];
    %!promises{$k} = Promise.start( {
        self!encode-element: ($k => $v);
      }
    );
  }
}}
  await %!promises.values;

  # Clear old entries
  @!encoded-entries = ();
  my $idx = 0;
  for %!document.keys -> $k {
#note "E1: $k";
    @!encoded-entries[$idx] = %!promises{$k}.result
      if %!promises{$k}.defined;

    $idx++;
  }


#`{{
  for ^@!keys.elems -> $idx {
    my $key = @!keys[$idx];
    next unless %!promises{$key}.defined;
    @!encoded-entries[$idx] = %!promises{$key}.result;
  }
}}
  %!promises = ();

  $idx = 0;
  for %!document.keys -> $k {
    given %!document{$k} {
      when Array {
        # The document for an array is a normal BSON document with integer
        # values for the keys counting with 0 and continuing sequentially.
        # For example, the array ['red', 'blue'] would be encoded as the
        # document ('0': 'red', '1': 'blue'). The keys must be in ascending
        # numerical order.
        my $pairs = (for .kv -> $ka, $va { "$ka" => $va });
        my BSON::Document $d .= new($pairs);
        @!encoded-entries[$idx] =
          [~] Buf.new(BSON::C-ARRAY), encode-e-name($k), $d.encode;
      }

      when BSON::Document {
        @!encoded-entries[$idx] =
          [~] Buf.new(BSON::C-DOCUMENT), encode-e-name($k), .encode;
      }

      when Hash::Ordered {
        @!encoded-entries[$idx] =
          [~] Buf.new(BSON::C-DOCUMENT), encode-e-name($k), .encode;
      }
    }

    $idx++;
  }

#`{{
  # filling the gaps of arays and nested documents
  for ^@!keys.elems -> $idx {
    my $key = @!keys[$idx];
    if @!values[$idx] ~~ Array {

      # The document for an array is a normal BSON document with integer values
      # for the keys counting with 0 and continuing sequentially.
      # For example, the array ['red', 'blue'] would be encoded as the document
      # ('0': 'red', '1': 'blue'). The keys must be in ascending numerical order.

      my $pairs = (for @!values[$idx].kv -> $k, $v { "$k" => $v });
      my BSON::Document $d .= new($pairs);
      @!encoded-entries[$idx] = [~] Buf.new(BSON::C-ARRAY),
                                    encode-e-name($key),
                                    $d.encode;
    }

    elsif @!values[$idx] ~~ BSON::Document {
      @!encoded-entries[$idx] = [~] Buf.new(BSON::C-DOCUMENT),
                                    encode-e-name($key),
                                    @!values[$idx].encode;
    }
  }
}}

  # if there are entries
  $!encoded-document = Buf.new;
  for @!encoded-entries -> $e {
    next unless $e.defined;
    $!encoded-document ~= $e;
  }

  # encode size: number of elems + null byte at the end
  my Buf $b = [~] encode-int32($!encoded-document.elems + 5),
      $!encoded-document,
      Buf.new(0x00);
  $b
}

#-------------------------------------------------------------------------------
# Encode a key value pair. Called from the insertion methods above when a
# key value pair is inserted.
#
# element ::= type-code e_name some-encoding
#
method !encode-element ( Pair:D $p --> Buf ) {
#note "Encode element ", $p.perl, ', ', $p.key.WHAT, ', ', $p.value.WHAT;

  my Buf $b;

  given $p.value {

    # skip all temporay containers
#      when TemporaryContainer {
#note "Tempvalue: KV: $p.perl()";
#        $b = [~] Buf.new()
#      }

	  when FatRat {
      # encode as binary FatRat
      # not yet implemented when proceding
      proceed;
    }

	  when Rat {
		  # Only handle Rat if it can be converted without precision loss
		  if $!convert-rat || $convert-rat {
        if $accept-loss || .Num.Rat(0) == $_ {
  			  $_ .= Num;

          # Now that Rat is converted to Num, proceed to encode the Num. But
          # when the Rat stays a Rat, it will end up in an exception.
          proceed;
        }

        else {
          die X::BSON.new(
            :operation<encode>,
            :type($_),
            :error('Rat can not be converted without losing pecision')
          );
        }
		  }

      else {
        # encode as binary Rat
        # not yet implemented when proceding
        proceed;
      }
	  }

    when Num {
      # Double precision
      # "\x01" e_name Num
      #
      $b = [~] Buf.new(BSON::C-DOUBLE),
               encode-e-name($p.key),
               encode-double($p.value);
    }

    when Str {
      # UTF-8 string
      # "\x02" e_name string
      #
      $b = [~] Buf.new(BSON::C-STRING),
               encode-e-name($p.key),
               encode-string($p.value);
    }

    when BSON::Document {
      # Embedded document
      # "\x03" e_name document
      # this handled separately after encoding is done for non-docs/arrays
    }

    when Array {
      # Array
      # "\x04" e_name document
      # this handled separately after encoding is done for non-docs/arrays
    }

    when BSON::Binary {
      # Binary data
      # "\x05" e_name int32 subtype byte*
      # subtype is '\x00' for the moment (Generic binary subtype)
      #
      $b = [~] Buf.new(BSON::C-BINARY), encode-e-name($p.key), .encode;
    }

    when BSON::ObjectId {
      # ObjectId
      # "\x07" e_name (byte*12)
      #
      $b = [~] Buf.new(BSON::C-OBJECTID), encode-e-name($p.key), .encode;
    }

    when Bool {
      # Bool
      # \0x08 e_name (\0x00 or \0x01)
      #
      if .Bool {
        # Boolean "true"
        # "\x08" e_name "\x01
        #
        $b = [~] Buf.new(BSON::C-BOOLEAN),
                 encode-e-name($p.key),
                 Buf.new(0x01);
      }
      else {
        # Boolean "false"
        # "\x08" e_name "\x00
        #
        $b = [~] Buf.new(BSON::C-BOOLEAN),
                 encode-e-name($p.key),
                 Buf.new(0x00);
      }
    }

    when DateTime {
      # UTC dateime
      # "\x09" e_name int64
      #
      $b = [~] Buf.new(BSON::C-DATETIME),
               encode-e-name($p.key),
               encode-int64((( .posix + .second - .whole-second) * 1000).Int);
    }

    when not .defined {
      # Nil == Undefined value == typed object
      # "\x0A" e_name
      #
      $b = Buf.new(BSON::C-NULL) ~ encode-e-name($p.key);
    }

    when BSON::Regex {
      # Regular expression
      # "\x0B" e_name cstring cstring
      #
      $b = [~] Buf.new(BSON::C-REGEX),
               encode-e-name($p.key),
               encode-cstring(.regex),
               encode-cstring(.options);
    }

#`{{
    when ... {
      # DBPointer - deprecated
      # "\x0C" e_name string (byte*12)
      #
      die X::BSON.new(
        :operation('encoding DBPointer'), :type('0x0C'),
        :error('DBPointer is deprecated')
      );
    }
}}

    # This entry does 2 codes. 0x0D for javascript only and 0x0F when
    # there is a scope document defined in the object
    #
    when BSON::Javascript {

      # Javascript code
      # "\x0D" e_name string
      # "\x0F" e_name int32 string document
      #
      if .has-scope {
        $b = [~] Buf.new(BSON::C-JAVASCRIPT-SCOPE),
                 encode-e-name($p.key),
                 .encode;
      }

      else {
        $b = [~] Buf.new(BSON::C-JAVASCRIPT),
                 encode-e-name($p.key),
                 .encode;
      }
    }

    when Int {
      # Integer
      # "\x10" e_name int32
      # '\x12' e_name int64
      #
      if -0x7fffffff <= $p.value <= 0x7fffffff {
        $b = [~] Buf.new(BSON::C-INT32),
                 encode-e-name($p.key),
                 encode-int32($p.value);
      }

      elsif -0x7fffffff_ffffffff <= $p.value <= 0x7fffffff_ffffffff {
        $b = [~] Buf.new(BSON::C-INT64),
                 encode-e-name($p.key),
                 encode-int64($p.value);
      }

      else {
        my $reason = 'small' if $p.value < -0x7fffffff_ffffffff;
        $reason = 'large' if $p.value > 0x7fffffff_ffffffff;
        die X::BSON.new(
          :operation<encode>, :type<Int>,
          :error("Number too $reason")
        );
      }
    }

    when BSON::Timestamp {
      # timestamp as an unsigned 64 bit integer
      # '\x11' e_name int64
      $b = [~] Buf.new(BSON::C-TIMESTAMP),
               encode-e-name($p.key),
               encode-uint64($p.value);
    }

    when BSON::Decimal128 {
      #`{{
      $b = [~] Buf.new(BSON::C-DECIMAL128),
               encode-e-name($p.key),
               .encode;

      }}

      die X::BSON.new(
        :operation<encode>,
        :type($_),
        :error('Not yet implemented')
      );
    }

    default {
      die X::BSON.new( :operation<encode>, :type($_), :error('Not yet implemented'));
    }
  }

#note "\nEE: ", ", {$p.key} => {$p.value//'(Any)'}: ", $p.value.WHAT, ', ', $b;

  $b
}

#-------------------------------------------------------------------------------
# Decoding document
#-------------------------------------------------------------------------------
method decode ( Buf:D $data --> Nil ) {

  $!encoded-document = $data;

#    @!keys = ();
#    @!values = ();
  @!encoded-entries = ();

  # document decoding start: init index
  $!index = 0;

  # decode the document, then wait for any started parallel tracks
  # first get the size of the (nested-)document
  my Int $doc-size = decode-int32( $!encoded-document, $!index);
#note 'doc size: ', $doc-size;

  # step to the document content
  $!index += BSON::C-INT32-SIZE;

  # decode elements until end of doc (byte 0x00)
  while $!encoded-document[$!index] !~~ 0x00 {
#note "index: $!index, $!encoded-document[$!index]";
    self!decode-element;
  }

  # step over the last byte: index should now be the doc size
  $!index++;
#note "index: $!index == $doc-size";

  # check size of document with final byte location
  die X::BSON.new(
    :operation<decode>, :type<Document>,
    :error(
      [~] 'Size of document(', $doc-size,
          ') does not match with index(', $!index, ')'
    )
  ) if $doc-size != $!index;

  # wait for promises to end for this document
  self!process-decode-promises;
}

#-------------------------------------------------------------------------------
method !decode-element ( --> Nil ) {

  # Decode start point
  my $decode-start = $!index;

  # Get the value type of next pair
  my $bson-code = $!encoded-document[$!index++];

  # Get the key value, Index is adjusted to just after the 0x00
  # of the string.
  my Str $key = decode-e-name( $!encoded-document, $!index);
#note "$*THREAD.id() $key found, type 0x$bson-code.fmt('%02x'), idx now $!index";

  # Keys are pushed in the proper order as they are seen in the
  # byte buffer.
#    my Int $idx = @!keys.elems;
#    @!keys[$idx] = $key;              # index on new location == push()
  my Int $idx = @!encoded-entries.elems;
  my Int $size;

  given $bson-code {

    # 64-bit floating point
    when BSON::C-DOUBLE {

#`{{
      my $c = -> $i is copy {
        my $v = decode-double( $!encoded-document, $i);
#note "DBL: $key, $idx = @!values[$idx]";

        # Return total section of binary data
        ( $v, $!encoded-document.subbuf(
                $decode-start ..^            # At bson code
                ($i + BSON::C-DOUBLE-SIZE)   # $i is at code + key further
              )
        )
      }
}}

      my Int $i = $!index;
      $!index += BSON::C-DOUBLE-SIZE;
#note "DBL Subbuf: ", $!encoded-document.subbuf( $i, BSON::C-DOUBLE-SIZE);
      %!promises{$key} = Promise.start( {
          my $v = decode-double( $!encoded-document, $i);
#note "DBL: $key, $idx = @!values[$idx]";

          # Return total section of binary data
          ( $v, $!encoded-document.subbuf(
                  $decode-start ..^            # At bson code
                  ($i + BSON::C-DOUBLE-SIZE)   # $i is at code + key further
                )
          )
        }
      );
    }

    # String type
    when BSON::C-STRING {

      my Int $i = $!index;
      my Int $nbr-bytes = decode-int32( $!encoded-document, $!index);

      # Step over the size field and the null terminated string
      $!index += BSON::C-INT32-SIZE + $nbr-bytes;

      %!promises{$key} = Promise.start( {
          my $v = decode-string( $!encoded-document, $i);

          ( $v, $!encoded-document.subbuf(
                  $decode-start ..^
                  ($i + BSON::C-INT32-SIZE + $nbr-bytes)
                )
          )
        }
      );
    }

    # Nested document
    when BSON::C-DOCUMENT {
      my Int $i = $!index;
      my Int $doc-size = decode-int32( $!encoded-document, $i);
      $!index += $doc-size;

      # Wait for any threads to complete before decoding the subdocument
      # If not, the threads are eaten up and we end up waiting for
      # non-started threads.
      self!process-decode-promises;

      my BSON::Document $d .= new;
      $d.decode($!encoded-document.subbuf($i ..^ ($i + $doc-size)));

      %!promises{$key} = Promise.start( {
          ( $d, $!encoded-document.subbuf( $decode-start ..^ ($i + $doc-size)))
        }
      );
    }

    # Array code
    when BSON::C-ARRAY {

      my Int $i = $!index;
      my Int $doc-size = decode-int32( $!encoded-document, $!index);
      $!index += $doc-size;

      self!process-decode-promises;
      %!promises{$key} = Promise.start( {
          my BSON::Document $d .= new;

          $d.decode($!encoded-document.subbuf($i ..^ ($i + $doc-size)));
          my $v = [$d.values];

          ( $v, $!encoded-document.subbuf( $decode-start ..^ ($i + $doc-size)))
        }
      );
    }

    # Binary code
    # "\x05 e_name int32 subtype byte*
    # subtype = byte \x00 .. \x05, .. \xFF
    # subtypes \x80 to \xFF are user defined
    when BSON::C-BINARY {

      my Int $buf-size = decode-int32( $!encoded-document, $!index);
      my Int $i = $!index + BSON::C-INT32-SIZE;

      # Step over size field, subtype and binary data
      $!index += BSON::C-INT32-SIZE + 1 + $buf-size;

      %!promises{$key} = Promise.start( {
          my $v = BSON::Binary.decode(
            $!encoded-document, $i, :$buf-size
          );

          ( $v, $!encoded-document.subbuf(
                  $decode-start ..^ ($i + 1 + $buf-size)
                )
          )
        }
      );
    }

    # Object id
    when BSON::C-OBJECTID {

      my Int $i = $!index;
      $!index += 12;

      %!promises{$key} = Promise.start( {
          my $v = BSON::ObjectId.decode( $!encoded-document, $i);
          ( $v, $!encoded-document.subbuf($decode-start ..^ ($i + 12)))
        }
      );
    }

    # Boolean code
    when BSON::C-BOOLEAN {

      my Int $i = $!index;
      $!index++;

      %!promises{$key} = Promise.start( {
          my $v = $!encoded-document[$i] ~~ 0x00 ?? False !! True;
          ( $v, $!encoded-document.subbuf($decode-start .. ($i + 1)))
        }
      );
    }

    # Datetime code
    when BSON::C-DATETIME {
      my Int $i = $!index;
      $!index += BSON::C-INT64-SIZE;

      %!promises{$key} = Promise.start( {
          my $v = DateTime.new(
            decode-int64( $!encoded-document, $i) / 1000,
            :timezone(0)
          );

          ( $v, $!encoded-document.subbuf(
                  $decode-start ..^ ($i + BSON::C-INT64-SIZE)
                )
          )
        }
      );
    }

    # Null value -> Any
    when BSON::C-NULL {
      %!promises{$key} = Promise.start( {
          my $i = $!index;
          ( Any, $!encoded-document.subbuf($decode-start ..^ $i))
        }
      );
    }

    # regular expressions. these are perl5 like
    when BSON::C-REGEX {
      my $doc-size = $!encoded-document.elems;
      my $i1 = $!index;
      while $!encoded-document[$!index] !~~ 0x00 and $!index < $doc-size {
        $!index++;
      }
      $!index++;
      my $i2 = $!index;

      while $!encoded-document[$!index] !~~ 0x00 and $!index < $doc-size {
        $!index++;
      }
      $!index++;
      my $i3 = $!index;

      %!promises{$key} = Promise.start( {
          my $v = BSON::Regex.new(
            :regex(decode-cstring( $!encoded-document, $i1)),
            :options(decode-cstring( $!encoded-document, $i2))
          );

          ( $v, $!encoded-document.subbuf($decode-start ..^ $i3))
        }
      );
    }

    # Javascript code
    when BSON::C-JAVASCRIPT {

      # Get the size of the javascript code text, then adjust index
      # for this size and set i for the decoding. Then adjust index again
      # for the next action.
      my Int $i = $!index;
      my Int $buf-size = decode-int32( $!encoded-document, $i);

      # Step over size field and the javascript text
      $!index += (BSON::C-INT32-SIZE + $buf-size);

      %!promises{$key} = Promise.start( {
          my $v = BSON::Javascript.decode( $!encoded-document, $i);

          ( $v, $!encoded-document.subbuf(
                  $decode-start ..^ ($i + BSON::C-INT32-SIZE + $buf-size)
                )
          )
        }
      );
    }

    # Javascript code with scope
    when BSON::C-JAVASCRIPT-SCOPE {

      my Int $i1 = $!index;
      my Int $js-size = decode-int32( $!encoded-document, $i1);
      my Int $i2 = $!index + BSON::C-INT32-SIZE + $js-size;
      my Int $js-scope-size = decode-int32( $!encoded-document, $i2);

      $!index += (BSON::C-INT32-SIZE + $js-size + $js-scope-size);
      my Int $i3 = $!index;

      %!promises{$key} = Promise.start( {
          my $v = BSON::Javascript.decode(
            $!encoded-document, $i1,
            :bson-doc(BSON::Document.new),
            :scope(Buf.new($!encoded-document[$i2 ..^ ($i2 + $js-size)]))
          );

          ( $v, $!encoded-document.subbuf($decode-start ..^ $i3))
        }
      );
    }

    # 32-bit Integer
    when BSON::C-INT32 {

      my Int $i = $!index;
      $!index += BSON::C-INT32-SIZE;

      %!promises{$key} = Promise.start( {
          my $v = decode-int32( $!encoded-document, $i);
#note 'C-INT32:, ', $v;
          ( $v, $!encoded-document.subbuf(
                  $decode-start ..^ ($i + BSON::C-INT32-SIZE)
                )
          )
        }
      );
    }

    # timestamp
    when BSON::C-TIMESTAMP {

      my Int $i = $!index;
      $!index += BSON::C-UINT64-SIZE;

      %!promises{$key} = Promise.start( {
#            @!values[$idx] = BSON::Timestamp.new( :timestamp(
#                decode-uint64( $!encoded-document, $i)
#              )
#            );
          my $v = decode-uint64( $!encoded-document, $i);
#note "Timestamp: ", @!values[$idx];

          ( $v, $!encoded-document.subbuf(
                  $decode-start ..^ ($i + BSON::C-UINT64-SIZE)
                )
          )
        }
      );
    }

    # 64-bit Integer
    when BSON::C-INT64 {

      my Int $i = $!index;
      $!index += BSON::C-INT64-SIZE;

      %!promises{$key} = Promise.start( {
          my $v = decode-int64( $!encoded-document, $i);

          # return value and encoded snippet
          ( $v, $!encoded-document.subbuf(
                  $decode-start ..^ ($i + BSON::C-INT64-SIZE)
                )
          )
        }
      );
    }

    # 128-bit Decimal
    when BSON::C-DECIMAL128 {
      #`{{

      my Int $i = $!index;
      $!index += BSON::C-DECIMAL128-SIZE;

      %!promises{$key} = Promise.start( {
          @!values[$idx] = BSON::Decimal128.decode( $!encoded-document, $i);

          $!encoded-document.subbuf(
            $decode-start ..^ ($i + BSON::C-DECIMAL128-SIZE)
          );
        }
      );
    }}

      die X::BSON.new(
        :operation<decode>, :type($_),
        :error("BSON code '{.fmt('0x%02x')}' not yet implemented"),
      );
    }

    default {
      # We must stop because we do not know what the length should be of
      # this particular structure.
      die X::BSON.new(
        :operation<decode>,
        :error("BSON code '{.fmt('0x%02x')}' not implemented"),
        :type($_)
      );
    } # default
  } # given
} # method

#-------------------------------------------------------------------------------
method !process-decode-promises {
#note 'process-decode-promises: ', %!promises.elems, ', ', %!promises.keys;

#    if %!promises.elems {
    await Promise.allof(%!promises.values);
    my $idx = 0;
    for %!promises.keys -> $key {

#        if %!promises{$key}:exists {
        # Return the Buffer slices in each entry so it can be
        # concatenated again when encoding
#note "$*THREAD.id() Before wait for result of $key";
        ( %!document{$key}, @!encoded-entries[$idx]) = %!promises{$key}.result;
#note %!document{$key};
        $idx++;
#note "$*THREAD.id() After wait for $key";
#        } # if
    } # for

#`{{
    loop ( my $idx = 0; $idx < @!keys.elems; $idx++) {
      my $key = @!keys[$idx];
#note "$*THREAD.id() Prom from $key, $idx, {%!promises{$key}:exists}";

      if %!promises{$key}:exists {
        # Return the Buffer slices in each entry so it can be
        # concatenated again when encoding
#note "$*THREAD.id() Before wait for result of $key";
        ( @!values[$idx], @!encoded-entries[$idx]) = %!promises{$key}.result;
#note "$*THREAD.id() After wait for $key";
      } # if
    } # loop
}}

    %!promises = ();
#    } # if
} # method

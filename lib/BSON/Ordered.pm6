#TL:1:BSON::Ordered:

use v6.d;

#-------------------------------------------------------------------------------
=begin pod

=head1 BSON::Ordered

A role implementing Associativity.

=head1 Description

This role mimics the Hash behavior with a few differences because of the BSON specs. This role is used by L<the B<BSON::Document>|Document.html> where you can find other information.


=head1 Synopsis
=head2 Declaration

  unit class BSON::Ordered:auth<github:MARTIMM>;
  also does Associative;


=end pod

#-------------------------------------------------------------------------------
use Method::Also;

use BSON;
use BSON::Binary;
use BSON::Javascript;
use BSON::ObjectId;
use BSON::Regex;

#-------------------------------------------------------------------------------
unit role BSON::Ordered:auth<github:MARTIMM>:ver<0.2.0>;
also does Associative;

has Hash $.document = %();      # keys and values are stored here
has Array $!key-array = [];     # array to keep keys ordered

#-------------------------------------------------------------------------------
# Associative role methods
#-------------------------------------------------------------------------------
#TM:1:AT-KEY
=begin pod
=head1 Methods
=head2 AT-KEY

Look up a key and return its value. Please note that the key is automatically created when the key does not exist. In that case, an empty BSON::Document value is returned. This is necessary when an assignment to deep level keys are done. If you don't want this to happen, you may check the existence of a key first and decide on that outcome. See `:exists` below.

=head3 Example

  # look up a value
  say $document<some-key>;

  # assign a value. $document<a><b> is looked up and the last one is
  # taken care of by ASSIGN-KEY().
  $document<a><b><c> = 'abc';

=end pod

method AT-KEY ( Str $key --> Any ) {
#note "AT-KEY: $key";

  unless $!document{$key}:exists {
    $!key-array.push: $key;
    $!document{$key} = self.new
  }
  return-rw $!document{$key};
}

#-------------------------------------------------------------------------------
#TM:1:ASSIGN-KEY
=begin pod
=head2 ASSIGN-KEY

Define a key and assign a value to it.

=head3 Example

  $document<x> = 'y';

=end pod

method ASSIGN-KEY ( Str:D $key, Any $new ) {
#note "ASSIGN-KEY: $key";

  $!key-array.push: $key unless $!document{$key}:exists;
  $!document{$key} = self!walk-tree( self.new, $new);
}

#-------------------------------------------------------------------------------
#TM:1:BIND-KEY
=begin pod
=head2 BIND-KEY

Binding a value to a key.

=head3 Example

  my $y = 12345;
  $document<y> := $y;
  note $document<y>;   # 12345
  $y = 54321;
  note $document<y>;   # 54321

=end pod

method BIND-KEY ( Str $key, \new ) {
  $!document{$key} := new;
}

#-------------------------------------------------------------------------------
#TM:1:EXISTS-KEY
=begin pod
=head2 EXISTS-KEY

Check existence of a key

=head3 Example

  $document<Foo> = 'Bar' if $document<Foo>:!exists;

Do not check for undefinedness like below. In that case, when key did not exist, the key is created and set with an empty BSON::Document. C<//=> will then see that the value is defined and the assignment is not done;

  # this results in assignment of an empty BSON::Document
  $document<Foo> //= 'Bar';

=end pod

method EXISTS-KEY ( Str $key --> Bool ) {
  $!document{$key}:exists
}

#-------------------------------------------------------------------------------
#TM:1:DELETE-KEY
=begin pod
=head2 DELETE-KEY

Delete a key with its value. The value is returned.

=head3 Example

  my $old-foo-key-value = $document<Foo>:delete

=end pod

method DELETE-KEY ( Str $key --> Any ) {
  loop ( my Int $i = 0; $i < $!key-array.elems; $i++ ) {
    if $!key-array[$i] eq $key {
      $!key-array.splice( $i, 1);
      last;
    }
  }

  $!document{$key}:delete;
}

#-------------------------------------------------------------------------------
#TM:1:elems
=begin pod
=head2 elems

Return the number of keys and values in the document

=head3 Example

  say 'there are elements in the document' if $document.elems;

=end pod

method elems ( --> Int ) {
  $!document.elems
}

#-------------------------------------------------------------------------------
#TM:1:kv
=begin pod
=head2 kv

Return a sequence of key and value

=head3 Example

  for $document.kv -> $k, $v {
    …
  }

=end pod

method kv ( --> Seq ) {
  gather for @$!key-array -> $k {
    take $k;
    take $!document{$k};
  }
}

#-------------------------------------------------------------------------------
#TM:1:pairs
=begin pod
=head2 pairs

Get a sequence of pairs

=head3 Example

  for $document.pairs -> Pair $p {
    …
  }

=end pod

method pairs ( --> Seq ) {
  gather for @$!key-array -> $k {
    take $k => $!document{$k};
  }
}

#-------------------------------------------------------------------------------
#TM:1:keys
=begin pod
=head2 keys

Get a sequence of keys from the document.

=head3 Example

  for $document.keys -> Str $k {
    …
  }

=end pod

method keys ( --> Seq ) {
  gather for @$!key-array -> $k {
    take $k;
  }
}

#-------------------------------------------------------------------------------
#TM:1:values
=begin pod
=head2 values

=head3 Example

  for $document.values -> $v {
    …
  }

=end pod

method values ( --> Seq ) {
  gather for $!document{@$!key-array} -> $v {
    take $v;
  }
}

#-------------------------------------------------------------------------------
#TM:1:walk-tree
method !walk-tree ( %doc, $item --> Any ) {

  given $item {
    when Buf {
      return BSON::Binary.new(:data($item));
    }

    when Seq {
      for @$item -> Pair $i {
        %doc{$i.key} = self!walk-tree( self.new, $i.value);
      }

      return %doc;
    }

    when Array {
      my Array $a = [];
      for @$item -> $i {
        $a.push: self!walk-tree( self.new, $i);
      }

      return $a;
    }

    when Pair {
      %doc{$item.key} = self!walk-tree( self.new, $item.value);
      return %doc;
    }

    # A List should only contain Pair and is inserted in doc as kv pairs
    when List {
      for @$item -> Pair $i {
        %doc{$i.key} = self!walk-tree( self.new, $i.value);
      }

      return %doc;
    }

    when any( Rat, FatRat) {
      return $item.Num;
    }

    when Hash {
      die X::BSON.new(
        :operation("List $item"), :type<Hash>,
        :error("Values cannot be Hash")
      );
    }

    default {
      return $item;
    }
  }
}

#-------------------------------------------------------------------------------
#TM:1:raku
#TM:1:perl
=begin pod
=head2 raku, perl

Show the structure of a document

  method raku ( Int :$indent --> Str ) is also<perl>

=end pod

method raku ( Int :$indent is copy = 0, Bool :$no-end = False --> Str )
  is also<perl>
{
  my $s = [~] "\n", '  ' x $indent, "BSON::Document.new: (\n";
  for self.keys -> $key {
    $s ~= [~] '  ' x $indent + 1, $key, ' => ',
          show-tree( $!document{$key}, $indent + 1), "\n";
  }
  $s ~= [~] '  ' x $indent, ')', $no-end ?? '' !! ';', "\n";

  $s
}

#-------------------------------------------------------------------------------
sub show-tree ( $item, $indent is copy --> Str ) {

  my Str $s = '';

  given $item {
    when !.defined {
      $s = 'Undefined,';
    }

    when any( BSON::Binary, BSON::Javascript, BSON::ObjectId, BSON::Regex) {
      $s = $item.raku(:$indent);
    }

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

    when BSON::Ordered {
      $s = [~] " (\n";
      $indent++;
      for $item.keys -> $key {
        $s ~= [~] '  ' x $indent, $key, ' => ',
              show-tree( $item{$key}, $indent), "\n";
      }
      $indent--;
      $s ~= [~] '  ' x $indent, "),";
    }

    when Str {
      $s = [~] "'", $item, "',";
    }

    when Pair {
      $s = [~] $item.key, ' => ', $item.value, ",";
    }

    when Buf {
      $s = [~] $item.gist, ",";
    }

    default {
      $s = [~] $item, ",";
    }
  }

  $s
}

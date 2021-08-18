use v6.d;

#`{{
  Despite the nice module of Elizabeth, Hash::Ordered doesn't work for me. Two
  problems are noticed;
  - No autovivify -> made an issue #2 there and that will be solvable.
  - Assignments in that hash is out of reach but need to be converted
    e.g.

    my BSON::Document $d .= new;
    $d<abcdef> = a1 => 10, bb => 11;
    $d<abcdef><b1> = q => 255;

    The assignment to 'b1' should be converted into another Hash::Ordered
    instead of leaving it as a Pair. This also goes for several other values
    which need converting.
}}

unit class BSON::Ordered:auth<github:MARTIMM>:ver<0.1.0>;
also does Associative;

has Hash $.document = %();      # keys and values are stored here
has Array $!key-array = [];     # array to keep keys ordered

#-------------------------------------------------------------------------------
# Associative role methods
#-------------------------------------------------------------------------------
# Example: note $d<x>;
method AT-KEY ( Str $key --> Any ) {
#note "AT-KEY $key";
  unless $!document{$key}:exists {
    $!key-array.push: $key;
    $!document{$key} = BSON::Ordered.new
  }
  return-rw $!document{$key};
}

#-------------------------------------------------------------------------------
# Example: $d<x> = 'y';
#multi method ASSIGN-KEY ( Str:D $key, Seq:D $new --> Nil ) {
#note "ASSIGN-KEY Seq $key, $new, ", $new.WHAT;
#  self.ASSIGN-KEY( $key, $new.List);
#}

multi method ASSIGN-KEY ( Str:D $key, Any:D $new --> Nil ) {
#note "ASSIGN-KEY Any $key, $new, ", $new.WHAT;
  unless $!document{$key}:exists {
    $!key-array.push: $key;
  }

  $!document{$key} = walk-tree( BSON::Ordered.new, $new);
}

#-------------------------------------------------------------------------------
# Example: $d<y> := $y;
method BIND-KEY ( Str $key, \new ) {
note "BIND-KEY ";
  $!document{$key} := new;
}

#-------------------------------------------------------------------------------
# Example: $d<x>:exists;
method EXISTS-KEY ( Str $key --> Bool ) {
note "EXISTS-KEY ";
  $!document{$key}:exists
}

#-------------------------------------------------------------------------------
# Example: $d<x>:delete;
method DELETE-KEY ( Str $key --> Any ) {
note "DELETE-KEY ";
  $!document{$key}:delete
}

#-------------------------------------------------------------------------------
method elems ( --> Int ) {
#note ".elems\()";
  $!document.elems
#    @!keys.elems;
}

#-------------------------------------------------------------------------------
method kv ( --> Seq ) {
#note ".kv\()";
  gather for @$!key-array -> $k {
    take $k;
    take $!document{$k};
  }
}

#-------------------------------------------------------------------------------
method pairs ( --> Seq ) {
#note ".pairs\()";
  gather for @$!key-array -> $k {
    take $k => $!document{$k};
  }
}

#-------------------------------------------------------------------------------
method keys ( --> List ) {
#note ".keys\()";
  $!key-array
}

#-------------------------------------------------------------------------------
method values ( --> List ) {
#note ".values\()";
  $!document{@$!key-array}.list
}

#-------------------------------------------------------------------------------
sub walk-tree ( %doc, $item --> Any ) {

  given $item {
    when !.defined {
note "Any";
      die X::BSON.new(
        :operation("List $item"), :type<Hash>,
        :error("Values cannot be undefined")
      );
    }

    when Seq {
note "Seq";
      for @$item -> Pair $i {
        %doc{$i.key} = walk-tree( BSON::Ordered.new, $i.value);
      }

      return %doc;
    }

    when Array {
note "Array";
      my Array $a = [];
      for @$item -> $i {
        $a.push: walk-tree( BSON::Ordered.new, $i);
      }

      return $a;
    }

    when Pair {
note "Pair: $item.key(), $item.value()";
      %doc{$item.key} = walk-tree( BSON::Ordered.new, $item.value);
      return %doc;
    }

    # A List should only contain Pair and is inserted in doc as kv pairs
    when List {
note "List";
      for @$item -> Pair $i {
        %doc{$i.key} = walk-tree( BSON::Ordered.new, $i.value);
      }

      return %doc;
    }
#`{{
    when BSON::Document {
      return $item.document;
    }
}}
#`{{
    when BSON::Ordered {
note "wt2 HO: $item.keys(), $item.values()";
      for $item.keys -> $k {
        %doc{$k} = walk-tree( BSON::Ordered.new, $item{$k});
      }
      return %doc;
    }
}}

    when Hash {
note "Hash";
      die X::BSON.new(
        :operation("List $item"), :type<Hash>,
        :error("Values cannot be Hash")
      );
    }

    default {
#note "default $item, ", $item.WHAT;
      return $item ~~ Rat ?? $item.Num !! $item;
    }
  }
}

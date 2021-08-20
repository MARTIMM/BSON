use v6.d;

use Method::Also;

use BSON;

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

unit role BSON::Ordered:auth<github:MARTIMM>:ver<0.1.0>;
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
    $!document{$key} = self.new
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

  $!document{$key} = self.walk-tree( self.new, $new);
}

#-------------------------------------------------------------------------------
# Example: $d<y> := $y;
method BIND-KEY ( Str $key, \new ) {
#note "BIND-KEY ";
  $!document{$key} := new;
}

#-------------------------------------------------------------------------------
# Example: $d<x>:exists;
method EXISTS-KEY ( Str $key --> Bool ) {
#note "EXISTS-KEY ";
  $!document{$key}:exists
}

#-------------------------------------------------------------------------------
# Example: $d<x>:delete;
method DELETE-KEY ( Str $key --> Any ) {
#note "DELETE-KEY ";
  loop ( my Int $i = 0; $i < $!key-array.elems; $i++ ) {
    if $!key-array[$i] eq $key {
      $!key-array.splice( $i, 1);
      last;
    }
  }

  $!document{$key}:delete;
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
method keys ( --> Seq ) {
#note ".keys\()";
  gather for @$!key-array -> $k {
    take $k;
  }
}

#-------------------------------------------------------------------------------
method values ( --> Seq ) {
#note ".values\()";
  gather for $!document{@$!key-array} -> $v {
    take $v;
  }
}

#-------------------------------------------------------------------------------
method walk-tree ( %doc, $item --> Any ) {

  given $item {
    when !.defined {
#note "Any";
      die X::BSON.new(
        :operation("List $item"), :type<Hash>,
        :error("Values cannot be undefined")
      );
    }

    when Seq {
#note "Seq";
      for @$item -> Pair $i {
        %doc{$i.key} = self.walk-tree( self.new, $i.value);
      }

      return %doc;
    }

    when Array {
#note "Array";
      my Array $a = [];
      for @$item -> $i {
        $a.push: self.walk-tree( self.new, $i);
      }

      return $a;
    }

    when Pair {
#note "Pair: $item.key(), $item.value()";
      %doc{$item.key} = self.walk-tree( self.new, $item.value);
      return %doc;
    }

    # A List should only contain Pair and is inserted in doc as kv pairs
    when List {
#note "List";
      for @$item -> Pair $i {
        %doc{$i.key} = self.walk-tree( self.new, $i.value);
      }

      return %doc;
    }
#`{{
    when BSON::Document {
      return $item.document;
    }
}}
#`{{
    when self {
note "wt2 HO: $item.keys(), $item.values()";
      for $item.keys -> $k {
        %doc{$k} = self.walk-tree( self.new, $item{$k});
      }
      return %doc;
    }
}}

    when Hash {
#note "Hash";
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

#-------------------------------------------------------------------------------
method raku ( Int :$indent is copy = 0 --> Str ) is also<perl> {
  my $s = [~] "\n", '  ' x $indent, "BSON::Document.new: (\n";
  for self.keys -> $key {
    $s ~= [~] '  ' x $indent + 1, $key, ' => ',
          show-tree( $!document{$key}, $indent + 1), "\n";
  }
  $s ~= [~] '  ' x $indent, ");\n";

  $s
}

#-------------------------------------------------------------------------------
sub show-tree ( $item, $indent is copy --> Str ) {

  my Str $s = '';
#note $item, ', ', $item.^name ~~ 'BSON::Ordered' ?? 'HO' !! $item.WHAT;

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

    when BSON::Ordered {
      $s = [~] "BSON::Document.new((\n";
      $indent++;
#note 'BO: ', $item.keys;
      for $item.keys -> $key {
#note 'BO k: ', $key;
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

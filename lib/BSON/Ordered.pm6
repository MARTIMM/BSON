use v6.d;

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
method ASSIGN-KEY ( Str:D $key, Any $new ) {
  $!key-array.push: $key unless $!document{$key}:exists;
  $!document{$key} = self.walk-tree( self.new, $new);
}

#-------------------------------------------------------------------------------
# Example: $d<y> := $y;
method BIND-KEY ( Str $key, \new ) {
  $!document{$key} := new;
}

#-------------------------------------------------------------------------------
# Example: $d<x>:exists;
method EXISTS-KEY ( Str $key --> Bool ) {
  $!document{$key}:exists
}

#-------------------------------------------------------------------------------
# Example: $d<x>:delete;
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
method of ( ) {
  BSON::Ordered;
}

#-------------------------------------------------------------------------------
method elems ( --> Int ) {
  $!document.elems
}

#-------------------------------------------------------------------------------
method kv ( --> Seq ) {
  gather for @$!key-array -> $k {
    take $k;
    take $!document{$k};
  }
}

#-------------------------------------------------------------------------------
method pairs ( --> Seq ) {
  gather for @$!key-array -> $k {
    take $k => $!document{$k};
  }
}

#-------------------------------------------------------------------------------
method keys ( --> Seq ) {
  gather for @$!key-array -> $k {
    take $k;
  }
}

#-------------------------------------------------------------------------------
method values ( --> Seq ) {
  gather for $!document{@$!key-array} -> $v {
    take $v;
  }
}

#-------------------------------------------------------------------------------
method walk-tree ( %doc, $item --> Any ) {

  given $item {
    when Buf {
      return BSON::Binary.new(:data($item));
    }

    when Seq {
      for @$item -> Pair $i {
        %doc{$i.key} = self.walk-tree( self.new, $i.value);
      }

      return %doc;
    }

    when Array {
      my Array $a = [];
      for @$item -> $i {
        $a.push: self.walk-tree( self.new, $i);
      }

      return $a;
    }

    when Pair {
      %doc{$item.key} = self.walk-tree( self.new, $item.value);
      return %doc;
    }

    # A List should only contain Pair and is inserted in doc as kv pairs
    when List {
      for @$item -> Pair $i {
        %doc{$i.key} = self.walk-tree( self.new, $i.value);
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

use v6.d;

#-------------------------------------------------------------------------------
use NativeCall;

use BSON;
use BSON::ObjectId;
use BSON::Regex;
use BSON::Javascript;
use BSON::Binary;
use BSON::Decimal128;

use BSON::Ordered;

#-------------------------------------------------------------------------------
unit class BSON::Document:auth<github:MARTIMM>:ver<0.2.0>;
also does BSON::Ordered;

#-------------------------------------------------------------------------------
# Initializing
#-------------------------------------------------------------------------------
# - %options must be empty. If not, it is a Hash -> illegal
# - item types can be;
#   - Undefined           .new;
#   - A Pair              .new: :a<b>;
#   - List of Pair        .new: :a<b>,;
#   - Seq of Pair         .new: ('count00', *.succ ... 'count10') Z=> 0 xx 10;
#   - BSON::Document
#   - BSON::Ordered
#   - A Buf               import encoded data
#   - A CArray[byte]
# - Illegal;
#   - Hash and friends    .new(:a<b>);
#   - Array               .new([ 0, 1, 2]);
method new( $item?, *%options ) {

  die X::BSON.new(
    :operation("new: Hash %options.gist()"), :type<Hash>,
    :error("Arguments cannot be Hash")
  ) if %options.elems;

  my BSON::Document $d;
  given $item {
    when Buf {
      $d .= new;
      $d = $d.decode($item);
    }

    when CArray[byte] {
      my Buf $length-field .= new($item[0..3]);
      my Int $doc-size = $length-field.read-uint32( 0, LittleEndian);

      # And get all bytes into the Buf and convert it back to a BSON document
      $d = $d.decode(Buf.new( $item[0..($doc-size-1)] ));
    }
  }

  $d //= self.bless(:$item);

  $d
}

#-------------------------------------------------------------------------------
submethod BUILD ( :$item ) {

  given $item {
    when Pair {
      self{$item.key} = $item.value; #self.walk-tree( $!document, $item.value);
    }

    when Array {
      die X::BSON.new(
        :operation("new: type Array cannot be a top level object"),
        :type($item.^name), :error("Unsupported type")
      );
    }

    when Seq {
      for @$item -> Pair $p {
        self{$p.key} = $p.value; #self.walk-tree( BSON::Document.new, $p.value);
      }
    }

    when List {
      for @$item -> Pair $p {
        self{$p.key} = $p.value; #self.walk-tree( BSON::Document.new, $p.value);
      }
    }

    # supporting old ways
    when any( BSON::Ordered, BSON::Ordered) {
      for $item.keys -> $k {
        self{$k} = $item{$k};
      }
    }

    when Any { }

    default {
      die X::BSON.new(
        :operation("new: type {$item.^name} not supported"),
        :type($item.^name), :error("Unsupported type")
      );
    }
  }
}

#-------------------------------------------------------------------------------
method of ( ) {
  BSON::Document;
}

#-------------------------------------------------------------------------------
method decode ( Buf $b, :$decoder is copy --> BSON::Document ) {
  unless $decoder {
    require ::('BSON::Decode');
    $decoder = ::('BSON::Decode').new;
  }

  $decoder.decode($b)
}

#-------------------------------------------------------------------------------
method encode ( :$encoder is copy --> Buf ) {
  unless ?$encoder {
    require ::('BSON::Encode');
    $encoder = ::('BSON::Encode').new;
  }

  $encoder.encode(self)
}

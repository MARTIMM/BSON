use v6;

package BSON {
  use BSON::Exception;

  class ObjectId {

    # Represents ObjectId BSON type described in
    # http://dochub.mongodb.org/core/objectids
    #
    has Buf $.oid;


    multi method new ( Buf $b ) {
      die 'ObjectId must be exactly 12 bytes' unless $b.elems ~~ 12;
      self.bless( *, oid => $b);
    }

    multi method new ( Str $s ) {
      my @a = map {:16($_) }, $s.comb(/../);
      my Buf $b = Buf.new(@a);
      die 'ObjectId must be exactly 12 bytes' unless $b.elems ~~ 12;
      self.bless( *, oid => $b);
    }


    method decode ( Buf $b --> BSON::ObjectId ) {
      die X::BSON::Parse.new(
        :operation('BSON::ObjectId::decode'),
        :error("Buffer doesn't have 12 bytes")
      ) unless $b.elems == 12;

      return self.bless( *, oid => $b);
    }

    method encode ( Str $s --> BSON::ObjectId ) {
      # Check length of string
      #
      my $l = $s.chars;
      die X::BSON::Parse.new(
        :operation('BSON::ObjectId::encode'),
        :error("String has $l characters, must be 12")
      ) unless $l == 12;

      # Check if all characters are hex characters.
      #
      die X::BSON::Parse.new(
        :operation('BSON::ObjectId::encode'),
        :error("String is not a hexadecimal number")
      ) unless $s ~~ m:i/^ <[0..9a..f]>+ $/;

      my @a = map {:16($_) }, $s.comb(/../);
      my Buf $b = Buf.new(@a);
      return self.bless( *, oid => $b);
    }


    method Buf ( ) {
      return $.oid;
    }

    method perl ( ) {
      my $s = '';
      for $.oid.list {
        $s ~= ( $_ +> 4 ).fmt('%x') ~ ( $_ % 16 ).fmt('%x');
      }

      return 'ObjectId( "' ~ $s ~ '" )';
    }
  }
}

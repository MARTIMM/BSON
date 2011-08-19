class BSON::ObjectId;

# Represents ObjectId BSON type described in
# http://dochub.mongodb.org/core/objectids

has Buf $!oid is rw;

multi method new( Buf $oid ) {

    die 'ObjectId must be exactly 12 bytes'
        unless +$oid.contents ~~ 12;

    self.bless( *, oid => $oid );
}


multi method new( Str $oid ) {

    my Buf $b = pack( 'H', $oid );

    die 'ObjectId must be exactly 12 bytes'
        unless +$b.contents ~~ 12;

    self.bless( *, oid => $b );
}


method Str ( ) {

    return 'ObjectId( "' ~ $!oid.unpack( 'H' ) ~ '" )';
}

method Buf ( ) {

    return $!oid;
}
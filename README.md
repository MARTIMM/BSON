# BSON support

![Face](http://modules.perl6.org/logos/BSON.png)

Implements [BSON specification](http://bsonspec.org/).

Compatible with Perl 6 [Rakudo Star](http://rakudo.org/) 2012.01+.


## SYNOPSIS

    my $b = BSON.new;
    my Buf $encoded = $b.encode(
        {
            "_id" => BSON::ObjectId.new( "4e4987edfed4c16f8a56ed1d" ),
            "some string"   => "foo",
            "some number"   => 123,
            "some array"    => [ ],
            "some hash"     => { },
            "some bool"     => Bool::True,
        }
    );
    my $decoded = $b.decode( $encoded );


## NATIVE TYPES

    Perl6           <=>         BSON
    
    Str             <=>         UTF-8 string
    Int             <=>         32-bit Integer
    Bool            <=>         Boolean "true" / "false"
    Array           <=>         Array
    Hash            <=>         Embedded document
    BSON::ObjectId  <=>         ObjectId

`Rat`, `Real` - Not Yet Implemented


## EXTENDED TYPES

```BSON::ObjectId``` - Internal representation is 12 bytes,
but to keep it consistent with MongoDB presentation described in
[ObjectId spec](http://dochub.mongodb.org/core/objectids)
constructor accepts string containing 12 hex pairs:

    BSON::ObjectId.new( '4e4987edfed4c16f8a56ed1d' )

Internal ```Buf``` can be reached by `.Buf` accessor.
Method ```.perl``` is available for easy debug.


## CONTACT

You can find me (and many awesome people who helped me to develop this module)
on irc.freenode.net #perl6 channel as __bbkr__.
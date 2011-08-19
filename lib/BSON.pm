class BSON;

use BSON::ObjectId;

# The int32 is the total number of bytes comprising the document.
has Int $int32 = 2147483647;

method encode ( %h ) {

    return self._document( %h );
}

method decode ( Buf $b is copy ) {

    return self._document( $b );
}

multi method _document ( %h ) {
    # BSON Document
    # document ::= int32 e_list "\x00"

    # The int32 is the total number of bytes comprising the document.

    my $l = self._e_list( %h.pairs );

    return self._int32( +$l.contents + 5 ) ~ $l ~ Buf.new( 0x00 );
}

multi method _document ( Buf $b ) {
    # BSON Document
    # document ::= int32 e_list "\x00"

    # The int32 is the total number of bytes comprising the document.

    my $s = +$b.contents;

    my $i = self._int32( $b );

    my %h = self._e_list( $b );

    die 'Parse error' unless $b.contents.shift ~~ 0x00;

    die 'Parse error' unless $s ~~ +$b.contents + $i;

    return %h;
}

multi method _e_list ( @p ) {
    # Sequence of elements
    # e_list ::= element e_list
    # | ""

    my Buf $l = Buf.new( );

    for @p -> $p {
        $l = $l ~ self._element( $p );
    }

    return $l;
}

multi method _e_list ( Buf $b ) {
    # Sequence of elements
    # e_list ::= element e_list
    # | ""

    my @p;

    # Parse elements until _document ends
    while $b.[ 0 ] !~~ 0x00 {
        push @p, self._element( $b );
    }

    return @p;
}

multi method _element ( Pair $p ) {

    given $p.value {

        when not .defined {
            # Null value
            # "\x0A" e_name

            return Buf.new( 0x0A ) ~ self._e_name( $p.key );
        }

        when Str {
            # UTF-8 string
            # "\x02" e_name string

            return Buf.new( 0x02 ) ~ self._e_name( $p.key ) ~ self._string( $p.value );
        }

        when Int {
            # 32-bit Integer
            # "\x10" e_name int32

            return Buf.new( 0x10 ) ~ self._e_name( $p.key ) ~ self._int32( $p.value );
        }

        when Bool {

            if .Bool {
                # Boolean "true"
                # "\x08" e_name "\x01

                return Buf.new( 0x08 ) ~ self._e_name( $p.key ) ~ Buf.new( 0x01 );
            }
            else {
                # Boolean "false"
                # "\x08" e_name "\x00

                return Buf.new( 0x08 ) ~ self._e_name( $p.key ) ~ Buf.new( 0x00 );
            }

        }

        when Array {
            # Array
            # "\x04" e_name document

            # The document for an array is a normal BSON document
            # with integer values for the keys,
            # starting with 0 and continuing sequentially.
            # For example, the array ['red', 'blue']
            # would be encoded as the document {'0': 'red', '1': 'blue'}.
            # The keys must be in ascending numerical order.

            my %h = .kv;

            return Buf.new( 0x04 ) ~  self._e_name( $p.key ) ~ self._document( %h );
        }

        when Hash {
            # Embedded document
            # "\x03" e_name document

            return Buf.new( 0x03 ) ~  self._e_name( $p.key ) ~ self._document( $_ );
        }

        when BSON::ObjectId {
            # ObjectId
            # "\x07" e_name (byte*12)

            return Buf.new( 0x07 ) ~ self._e_name( $p.key ) ~ .Buf;
        }

        default {

            die 'Sorry, not yet supported type: ' ~ .WHAT;
        }

    }

}

multi method _element ( Buf $b ) {

    given $b.contents.shift {

        when 0x0A {
            # Null value
            # "\x0A" e_name

            return self._e_name( $b ) => Any;
        }

        when 0x02 {
            # UTF-8 string
            # "\x02" e_name string

            return self._e_name( $b ) => self._string( $b );
        }

        when 0x10 {
            # 32-bit Integer
            # "\x10" e_name int32

            return self._e_name( $b ) => self._int32( $b );
        }

        when 0x08 {
            my $n = self._e_name( $b );

            given $b.contents.shift {

                when 0x01 {
                    # Boolean "true"
                    # "\x08" e_name "\x01

                    return $n => Bool::True;
                }

                when 0x00 {
                    # Boolean "false"
                    # "\x08" e_name "\x00

                    return $n => Bool::False;
                }

                default {

                    die 'Parse error';
                }

            }

        }

        when 0x04 {
            # Array
            # "\x04" e_name document

            # The document for an array is a normal BSON document
            # with integer values for the keys,
            # starting with 0 and continuing sequentially.
            # For example, the array ['red', 'blue']
            # would be encoded as the document {'0': 'red', '1': 'blue'}.
            # The keys must be in ascending numerical order.

            return self._e_name( $b ) => [ self._document( $b ).values ];
        }

        when 0x03 {
            # Embedded document
            # "\x03" e_name document

            return self._e_name( $b )  => self._document( $b );
        }

        when 0x07 {
            # ObjectId
            # "\x07" e_name (byte*12)

            my $n = self._e_name( $b );

            my $a = Buf.new( );

            $a.contents.push( $b.contents.shift ) for ^ 12;

            return $n => BSON::ObjectId.new( $a );
        }

        default {

            die 'Sorry, not yet supported type: ' ~ $_;
        }

    }

}

multi method _int32 ( Int $i ) {
    # 4 bytes (32-bit signed integer)

    return pack( 'V', $i);
}

multi method _int32 ( Buf $b ) {
    # 4 bytes (32-bit signed integer)

    my $a = Buf.new( );

    $a.contents.push( $b.contents.shift ) for ^ 4;

    return $a.unpack( 'V' );
}

multi method _e_name ( Str $s ) {
    # Key name
    # e_name ::= cstring

    return self._cstring( $s );
}

multi method _e_name ( Buf $b ) {
    # Key name
    # e_name ::= cstring

    return self._cstring( $b );
}

multi method _string ( Str $s ) {
    # String
    # string ::= int32 (byte*) "\x00"

    # The int32 is the number bytes in the (byte*) + 1 (for the trailing '\x00').
    # The (byte*) is zero or more UTF-8 encoded characters.

    return self._int32( $s.bytes + 1 ) ~ $s.encode( 'utf-8' ) ~ Buf.new( 0x00 );
}

multi method _string ( Buf $b ) {
    # String
    # string ::= int32 (byte*) "\x00"

    # The int32 is the number bytes in the (byte*) + 1 (for the trailing '\x00').
    # The (byte*) is zero or more UTF-8 encoded characters.

    my $i = self._int32( $b );
    my $a = Buf.new( );

    for ^ ( $i - 1 ) {
        push $a.contents, $b.contents.shift;
    }

    die 'Parse error' unless $b.contents.shift ~~ 0x00;

    return $a.decode( 'utf-8' );
}

multi method _cstring ( Str $s ) {
    # CString
    # cstring ::= (byte*) "\x00"

    # Zero or more modified UTF-8 encoded characters followed by '\x00'.
    # The (byte*) MUST NOT contain '\x00', hence it is not full UTF-8.

    if $s ~~ /\x00/ {
        die "Forbidden 0x00 sequence in $s"
    }

    return $s.encode( 'utf-8' ) ~ Buf.new( 0x00 );
}

multi method _cstring ( Buf $b ) {
    # CString
    # cstring ::= (byte*) "\x00"

    # Zero or more modified UTF-8 encoded characters followed by '\x00'.
    # The (byte*) MUST NOT contain '\x00', hence it is not full UTF-8.

    my $a = Buf.new( );

    while $b.[ 0 ] !~~ 0x00 {
        push $a.contents, $b.contents.shift;
    }

    die 'Parse error' unless $b.contents.shift ~~ 0x00;

    return $a.decode( 'utf-8' );
}


# HACK to concatenate 2 Buf()s
# workaround for https://rt.perl.org/rt3/Public/Bug/Display.html?id=96430
multi sub infix:<~>(Buf $a, Buf $b) {

    return Buf.new( $a.contents.list, $b.contents.list );
}


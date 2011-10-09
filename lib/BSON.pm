class BSON;

use BSON::ObjectId;


method encode ( %h ) {

    return self._document( %h );
}

method decode ( Buf $b ) {

    return self._document( $b.list );
}


# BSON Document
# document ::= int32 e_list "\x00"

# The int32 is the total number of bytes comprising the document.

multi method _document ( %h ) {
    
    my $l = self._e_list( %h.pairs );

    return self._int32( $l.elems + 5 ) ~ $l ~ Buf.new( 0x00 );
}

multi method _document ( Array $a ) {

    my $s = $a.elems;

    my $i = self._int32( $a );

    my %h = self._e_list( $a );

    die 'Parse error' unless $a.shift ~~ 0x00;

    die 'Parse error' unless $s ~~ $a.elems + $i;

    return %h;
}


# Sequence of elements
# e_list ::= element e_list
# | ""

multi method _e_list ( @p ) {

    my Buf $b = Buf.new( );

    for @p -> $p {
        $b = $b ~ self._element( $p );
    }

    return $b;
}

multi method _e_list ( Array $a ) {

    my @p;
    while $a[ 0 ] !~~ 0x00 {
        push @p, self._element( $a );
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

multi method _element ( Array $a ) {

    given $a.shift {

        when 0x0A {
            # Null value
            # "\x0A" e_name

            return self._e_name( $a ) => Any;
        }

        when 0x02 {
            # UTF-8 string
            # "\x02" e_name string

            return self._e_name( $a ) => self._string( $a );
        }

        when 0x10 {
            # 32-bit Integer
            # "\x10" e_name int32

            return self._e_name( $a ) => self._int32( $a );
        }

        when 0x08 {
            my $n = self._e_name( $a );

            given $a.shift {

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

            return self._e_name( $a ) => [ self._document( $a ).values ];
        }

        when 0x03 {
            # Embedded document
            # "\x03" e_name document

            return self._e_name( $a )  => self._document( $a );
        }

        when 0x07 {
            # ObjectId
            # "\x07" e_name (byte*12)

            my $n = self._e_name( $a );

            my @a;
            @a.push( $a.shift ) for ^ 12;

            return $n => BSON::ObjectId.new( Buf.new( @a ) );
        }

        default {

            die 'Sorry, not yet supported type: ' ~ $_;
        }

    }

}


# 4 bytes (32-bit signed integer)
multi method _int32 ( Int $i ) {
    
    return Buf.new( $i % 0x100, $i +> 0x08 % 0x100, $i +> 0x10 % 0x100, $i +> 0x18 % 0x100 );
}

multi method _int32 ( Array $a ) {

    return [+] $a.shift, $a.shift +< 0x08, $a.shift +< 0x10, $a.shift +< 0x18;
}


# Key name
# e_name ::= cstring

multi method _e_name ( Str $s ) {

    return self._cstring( $s );
}

multi method _e_name ( Array $a ) {

    return self._cstring( $a );
}


# String
# string ::= int32 (byte*) "\x00"

# The int32 is the number bytes in the (byte*) + 1 (for the trailing '\x00').
# The (byte*) is zero or more UTF-8 encoded characters.

multi method _string ( Str $s ) {

    return self._int32( $s.bytes + 1 ) ~ $s.encode( ) ~ Buf.new( 0x00 );
}

multi method _string ( Array $a ) {

    my $i = self._int32( $a );

    my @a;
    @a.push( $a.shift ) for ^ ( $i - 1 );
    
    die 'Parse error' unless $a.shift ~~ 0x00;

    return Buf.new( @a ).decode( );
}


# CString
# cstring ::= (byte*) "\x00"

# Zero or more modified UTF-8 encoded characters followed by '\x00'.
# The (byte*) MUST NOT contain '\x00', hence it is not full UTF-8.

multi method _cstring ( Str $s ) {

    die "Forbidden 0x00 sequence in $s" if $s ~~ /\x00/;

    return $s.encode( ) ~ Buf.new( 0x00 );
}

multi method _cstring ( Array $a ) {

    my @a;
    while $a[ 0 ] !~~ 0x00 {
        @a.push( $a.shift );
    }

    die 'Parse error' unless $a.shift ~~ 0x00;

    return Buf.new( @a ).decode( );
}

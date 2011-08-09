class BSON;

# The int32 is the total number of bytes comprising the document.
has Int $int32 = 2147483647;

method _document ( hash $h ) {
    # BSON Document
    # document ::= int32 e_list "\x00"
    
    # The int32 is the total number of bytes comprising the document.
    
    self._int32(  )
}

method _element ( Pair $p ) {
    
    
    my Buf $pair;
    for $o.kv -> $key, $value {
        given $value {
            # Null value
            # "\x0A" e_name
            when not .defined {
                $pair = Buf.new( "\x0A" ) ~ self._e_name( $key );
            }
            # UTF-8 string
            # "\x02" e_name string
            when Str {
                $pair = Buf.new( "\x02" ) ~ self._e_name( $key ) ~ self._string( $value );
            }
            # 32-bit Integer
            # "\x10" e_name int32
            when Int {
                $pair = Buf.new( "\x10" ) ~ self._e_name( $key ) ~ self._int32( $value );
            }
        }
    }
	 
}

method _int32 ( Int $i ) {
    # 4 bytes (32-bit signed integer)
    return pack( 'V', $l)
}

method _e_name ( Str $s ) {
    # Key name
    # e_name ::= cstring
    
    return self._cstring( $s );
}


method _string ( Str $s ) {
    # String
    # string ::= int32 (byte*) "\x00"
    
    # The int32 is the number bytes in the (byte*) + 1 (for the trailing '\x00').
    # The (byte*) is zero or more UTF-8 encoded characters.
    
    return self._int32( $s.bytes + 1 ) ~ $s.encode( 'utf-8' ) ~ Buf.new( "\x00" );
}

method _cstring ( Str $s ) {
    # CString
    # cstring ::= (byte*) "\x00"

    # Zero or more modified UTF-8 encoded characters followed by '\x00'.
    # The (byte*) MUST NOT contain '\x00', hence it is not full UTF-8.
    
    if $s ~~ /\x00/ {
        die "Forbidden 0x00 sequence in $s"
    }
    
    return $s.encode( 'utf-8' ) ~ Buf.new( "\x00" );
}

# HACK to concatenate 2 Buf()s
# workaround for https://rt.perl.org/rt3/Public/Bug/Display.html?id=96430
our multi sub infix:<~>(Buf $a, Buf $b) {

    return Buf.new( $a.contents.list, $b.contents.list );
}
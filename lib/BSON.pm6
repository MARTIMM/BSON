#TL:1:BSO:

use v6.d;

#-------------------------------------------------------------------------------
=begin pod

=head1 BSON

Provides subroutines for encoding and decoding

=head1 Description

This package provides simple encoding and decoding subroutines for the other classes and also constants are defined. Furthermore the B<X::BSON> exception class is defined.


=head1 Synopsis
=head2 Declaration

  unit class BSON:auth<github:MARTIMM>;


=end pod

#-------------------------------------------------------------------------------
use NativeCall;

#-------------------------------------------------------------------------------
#TT:1:Constants
=begin pod
=head1 Constants
=head2 Bson spec type constants

Codes which are used when encoding the B<BSON::Document> into a binary form.

  constant C-DOUBLE             = 0x01;
  constant C-STRING             = 0x02;
  constant C-DOCUMENT           = 0x03;
  constant C-ARRAY              = 0x04;
  constant C-BINARY             = 0x05;
  constant C-UNDEFINED          = 0x06;   # Deprecated
  constant C-OBJECTID           = 0x07;
  constant C-BOOLEAN            = 0x08;
  constant C-DATETIME           = 0x09;
  constant C-NULL               = 0x0A;
  constant C-REGEX              = 0x0B;
  constant C-DBPOINTER          = 0x0C;   # Deprecated
  constant C-JAVASCRIPT         = 0x0D;
  constant C-DEPRECATED         = 0x0E;   # Deprecated
  constant C-JAVASCRIPT-SCOPE   = 0x0F;
  constant C-INT32              = 0x10;
  constant C-TIMESTAMP          = 0x11;
  constant C-INT64              = 0x12;
  constant C-DECIMAL128         = 0x13;

  constant C-MIN-KEY            = 0xFF;
  constant C-MAX-KEY            = 0x7F;


=head2 Bson spec subtype constants

The following codes are used as a subtype to encode the binary type

  constant C-GENERIC            = 0x00;
  constant C-FUNCTION           = 0x01;
  constant C-BINARY-OLD         = 0x02;   # Deprecated
  constant C-UUID-OLD           = 0x03;   # Deprecated
  constant C-UUID               = 0x04;
  constant C-MD5                = 0x05;
  constant C-ENCRIPT            = 0x06;

  constant C-SPECIFIED          = 0x07;

  constant C-USERDEFINED-MIN    = 0x80;
  constant C-USERDEFINED-MAX    = 0xFF;

=head2 Some fixed sizes

  constant C-UUID-SIZE          = 16;
  constant C-MD5-SIZE           = 16;
  constant C-INT32-SIZE         = 4;
  constant C-INT64-SIZE         = 8;
  constant C-UINT64-SIZE        = 8;
  constant C-DOUBLE-SIZE        = 8;
  constant C-DECIMAL128-SIZE    = 16;

=end pod

package BSON:auth<github:MARTIM>:ver<0.2.1> {

  # BSON type codes
  constant C-DOUBLE             = 0x01;
  constant C-STRING             = 0x02;
  constant C-DOCUMENT           = 0x03;
  constant C-ARRAY              = 0x04;
  constant C-BINARY             = 0x05;
  constant C-UNDEFINED          = 0x06;         # Deprecated
  constant C-OBJECTID           = 0x07;
  constant C-BOOLEAN            = 0x08;
  constant C-DATETIME           = 0x09;
  constant C-NULL               = 0x0A;
  constant C-REGEX              = 0x0B;
  constant C-DBPOINTER          = 0x0C;         # Deprecated
  constant C-JAVASCRIPT         = 0x0D;
  constant C-DEPRECATED         = 0x0E;         # Deprecated
  constant C-JAVASCRIPT-SCOPE   = 0x0F;
  constant C-INT32              = 0x10;
  constant C-TIMESTAMP          = 0x11;
  constant C-INT64              = 0x12;
  constant C-DECIMAL128         = 0x13;

  constant C-MIN-KEY            = 0xFF;
  constant C-MAX-KEY            = 0x7F;

  #-----------------------------------------------------------------------------
  # Binary type codes
  constant C-GENERIC            = 0x00;
  constant C-FUNCTION           = 0x01;
  constant C-BINARY-OLD         = 0x02;         # Deprecated
  constant C-UUID-OLD           = 0x03;         # Deprecated
  constant C-UUID               = 0x04;
  constant C-MD5                = 0x05;
  constant C-ENCRIPT            = 0x06;

  constant C-SPECIFIED          = 0x07;

  constant C-USERDEFINED-MIN    = 0x80;
  constant C-USERDEFINED-MAX    = 0xFF;

  constant C-UUID-SIZE          = 16;
  constant C-MD5-SIZE           = 16;

  #-----------------------------------------------------------------------------
  # Fixed sizes
  constant C-INT32-SIZE         = 4;
  constant C-INT64-SIZE         = 8;
  constant C-UINT64-SIZE        = 8;
  constant C-DOUBLE-SIZE        = 8;
  constant C-DECIMAL128-SIZE    = 16;

  #-----------------------------------------------------------------------------
  subset Timestamp of UInt where ( $_ < (2**64 - 1 ) );
}

#-------------------------------------------------------------------------------
#TT:1:X::BSON
=begin pod
=head1 Exception class
=head2 X::BSON

Can be thrown when something is not right when defining the document, encoding or decoding the document or binary data.

When caught the following data is available
=item $x.operation; the operation wherein it occurs.
=item $x.type; a type when encoding or decoding.
=item $x.error; the why of the failure.

=end pod

class X::BSON is Exception {

  # No string types used because there can be lists of strings too
  has $.operation;                      # Operation method encode/decode
  has $.type;                           # Type to process
  has $.error;                          # Parse error

  method message ( --> Str ) {
    "$!operation\() on $!type, error: $!error\n";
  }
}

#-------------------------------------------------------------------------------
=begin pod
=head1 Exported subroutines
=end pod

#TS:1:encode-e-name
=begin pod
=head2 encode-e-name

  sub encode-e-name ( Str:D $s --> Buf )

=end pod
sub encode-e-name ( Str:D $s --> Buf ) is export {
  return encode-cstring($s);
}

#-------------------------------------------------------------------------------
#TS:1:encode-cstring
=begin pod
=head2 encode-cstring

  sub encode-cstring ( Str:D $s --> Buf )

=end pod
sub encode-cstring ( Str:D $s --> Buf ) is export {
  die X::BSON.new(
    :operation<encode>, :type<cstring>,
    :error("Forbidden 0x00 sequence in '$s'")
  ) if $s ~~ /\x00/;

  return $s.encode() ~ Buf.new(0x00);
}

#-------------------------------------------------------------------------------
#TS:1:encode-string
=begin pod
=head2 encode-string

  sub encode-string ( Str:D $s --> Buf )

=end pod
sub encode-string ( Str:D $s --> Buf ) is export {
  my Buf $b .= new($s.encode('UTF-8'));
  [~] Buf.new.write-int32( 0, $b.bytes + 1, LittleEndian), $b, Buf.new(0x00)
}

#-------------------------------------------------------------------------------
sub encode-int32 ( Int:D $i --> Buf ) is export is DEPRECATED('write-int32') {
  Buf.new.write-int32( 0, $i, LittleEndian);
}

#-------------------------------------------------------------------------------
sub encode-int64 ( Int:D $i --> Buf ) is export is DEPRECATED('write-int64') {
  Buf.new.write-int64( 0, $i, LittleEndian);
}

#-------------------------------------------------------------------------------
sub encode-uint64 ( UInt:D $i --> Buf )
  is export is DEPRECATED('write-uint64') {
  Buf.new.write-uint64( 0, $i, LittleEndian);
}

#-------------------------------------------------------------------------------
# encode Num in buf little endian
sub encode-double ( Num:D $r --> Buf ) is export is DEPRECATED('write-num64') {
  Buf.new.write-num64( 0, $r, LittleEndian);
}

#-------------------------------------------------------------------------------
#TS:1:decode-e-name
=begin pod
=head2 decode-e-name

  sub decode-e-name ( Buf:D $b, Int:D $index is rw --> Str )

=end pod
sub decode-e-name ( Buf:D $b, Int:D $index is rw --> Str ) is export {
  return decode-cstring( $b, $index);
}

#-------------------------------------------------------------------------------
#TS:1:decode-cstring
=begin pod
=head2 decode-cstring

  sub decode-cstring ( Buf:D $b, Int:D $index is rw --> Str )

=end pod
sub decode-cstring ( Buf:D $b, Int:D $index is rw --> Str ) is export {

  my @a;
  my $l = $b.elems;

  while $b[$index] !~~ 0x00 and $index < $l {
    @a.push($b[$index++]);
  }

  # This takes only place if there are no 0x00 characters found until the
  # end of the buffer which is almost never.
  die X::BSON.new(
    :operation<decode>, :type<cstring>,
    :error('Missing trailing 0x00')
  ) unless $index < $l and $b[$index++] ~~ 0x00;

  return Buf.new(@a).decode();
}

#-------------------------------------------------------------------------------
#TS:1:decode-string
=begin pod
=head2 decode-string

  sub decode-string ( Buf:D $b, Int:D $index --> Str )

=end pod
sub decode-string ( Buf:D $b, Int:D $index --> Str ) is export {

  my $size = $b.read-uint32( $index, LittleEndian);
  my $end-string-at = $index + 4 + $size - 1;

  # Check if there are enough letters left
  die X::BSON.new(
    :operation<decode>, :type<string>,
    :error('Not enough characters left')
  ) unless ($b.elems - $size) > $index;

  # Check if the end character is 0x00
  die X::BSON.new(
    :operation<decode>, :type<string>,
    :error('Missing trailing 0x00')
  ) unless $b[$end-string-at] == 0x00;

  return Buf.new($b[$index+4 ..^ $end-string-at]).decode;
}

#-------------------------------------------------------------------------------
sub decode-int32 ( Buf:D $b, Int:D $index --> Int )
  is export is DEPRECATED('read-int32') {
  $b.read-int32( $index, LittleEndian);
}

#-------------------------------------------------------------------------------
sub decode-int64 ( Buf:D $b, Int:D $index --> Int )
  is export is DEPRECATED('read-int64')  {
  $b.read-int64( $index, LittleEndian);
}

#-------------------------------------------------------------------------------
# decode unsigned 64 bit integer
sub decode-uint64 ( Buf:D $b, Int:D $index --> UInt )
  is export is DEPRECATED('read-uint64') {
  $b.read-uint64( $index, LittleEndian);
}

#-------------------------------------------------------------------------------
# decode to Num from buf little endian
sub decode-double ( Buf:D $b, Int:D $index --> Num )
  is export is DEPRECATED('read-num64') {
  $b.read-num64( $index, LittleEndian);
}

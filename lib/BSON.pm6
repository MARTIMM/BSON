use v6.c;

#-----------------------------------------------------------------------------
class X::BSON::Parse-objectid is Exception {

  # No string types used because there can be lists of strings too
  has $.operation;                      # Operation method
  has $.error;                          # Parse error

  method message () {
    return "\n$!operation\() error: $!error\n";
  }
}

#-------------------------------------------------------------------------------
class X::BSON::Parse-document is Exception {
  has $.operation;                      # Operation method
  has $.error;                          # Parse error

  method message () {
    return "\n$!operation error: $!error\n";
  }
}

#-------------------------------------------------------------------------------
class X::BSON::NYS is Exception {
  has $.operation;                      # Operation encode, decode
  has $.type;                           # Type to encode/decode

  method message () {
    return "\n$!operation error: BSON type '$!type' is not (yet) supported\n";
  }
}

#-------------------------------------------------------------------------------
class X::BSON::Deprecated is Exception {
  has $.operation;                      # Operation encode, decode
  has $.type;                           # Type to encode/decode
  has Int $.subtype;                    # Subtype of type

  method message () {
    my Str $m;
    if ?$!subtype {
      $m = "subtype '$!subtype' of BSON '$!type'";
    }

    else {
      $m = "BSON type '$!type'"
    }

    return "\n$!operation error: $m is deprecated\n";
  }
}


#-------------------------------------------------------------------------------
sub encode-int32 ( Int:D $i --> Buf ) is export {
  my int $ni = $i;

  return Buf.new(
    $ni +& 0xFF, ($ni +> 0x08) +& 0xFF,
    ($ni +> 0x10) +& 0xFF, ($ni +> 0x18) +& 0xFF
  );
}

#-------------------------------------------------------------------------------
sub decode-string ( Buf:D $b, Int:D $index is copy --> Str ) is export {

  my $size = decode-int32( $b, $index);
  my $end-string-at = $index + 4 + $size - 1;

  # Check if there are enaugh letters left
  #
  die X::BSON::Parse-document.new(
    :operation<decode-string>,
    :error('Not enaugh characters left')
  ) unless ($b.elems - $size) > $index;

  die X::BSON::Parse-document.new(
    :operation<decode-string>,
    :error('Missing trailing 0x00')
  ) unless $b[$end-string-at] == 0x00;

  return Buf.new($b[$index+4 ..^ $end-string-at]).decode;
}

#-------------------------------------------------------------------------------
sub decode-int32 ( Buf:D $b, Int:D $index --> Int ) is export {

  # Check if there are enaugh letters left
  #
  die X::BSON::Parse-document.new(
    :operation<decode-int32>,
    :error('Not enaugh characters left')
  ) if $b.elems - $index < 4;

  my int $ni = $b[$index]             +| $b[$index + 1] +< 0x08 +|
               $b[$index + 2] +< 0x10 +| $b[$index + 3] +< 0x18
               ;

  # Test if most significant bit is set. If so, calculate two's complement
  # negative number.
  # Prefix +^: Coerces the argument to Int and does a bitwise negation on
  # the result, assuming two's complement. (See
  # http://doc.perl6.org/language/operators^)
  # Infix +^ :Coerces both arguments to Int and does a bitwise XOR
  # (exclusive OR) operation.
  #
  $ni = (0xffffffff +& (0xffffffff+^$ni) +1) * -1  if $ni +& 0x80000000;
  return $ni;
}


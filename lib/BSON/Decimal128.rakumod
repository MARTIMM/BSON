use v6.d;

use BSON::Decimal128::Grammar;
use BSON::Decimal128::Actions;

#-------------------------------------------------------------------------------
unit class BSON::Decimal128:auth<github:MARTIMM>:ver<0.1.0>;

constant C-ZERO-ORD = '0'.ord;

# Decimal 32 bits values
#constant C--D32 = ;

# Decimal 64 bits values
#constant C--D64 = ;

# Decimal 128 bits values
constant C-BITS-D128 = 128;
constant C-BUFLEN-D128 = 16;
#constant C-EXPCONT-D128 = 12;
#constant C-TOTEXP-D128 = 14;
#constant C-COEFCONT-D128 = 110;
#constant C-TOTCOEFDIG-D128 = 34;
#constant C-EMAX-D128 = 6144;
#constant C-EMIN-D128 = -6143;
#constant C-ELIMIT-D128 = 12287;
#constant C-BIAS-D128 = 6176;


constant C-MANT-BITS-D128 = 112;
constant C-EXP-BIAS-D128 = 16383;
constant C-EXP-BITS-D128 = 15;

#-------------------------------------------------------------------------------
enum EndianType is export <little-endian big-endian system-endian>;

has $!endian = little-endian;
has Buf $.d128;

#-------------------------------------------------------------------------------
submethod BUILD ( EndianType :$!endian = little-endian ) { }

#-------------------------------------------------------------------------------
method encode ( --> Buf ) {

}

#-------------------------------------------------------------------------------
method decode (
  Buf:D $b,
  Int:D $index is copy,
  Int:D :$buf-size
  --> BSON::Decimal128
) {

}

#-------------------------------------------------------------------------------
method get-value ( --> Numeric ) {
}

#-------------------------------------------------------------------------------
multi method set-value ( Numeric $number ) {
}

#-------------------------------------------------------------------------------
multi method set-value ( Str $number ) {
  self.reset-buf;

  my BSON::Decimal128::Actions $actions .= new;
  my $matchObject = Decimal-Grammar.parse( $number, :$actions);

##`{{
  note "\n$?LINE $number";
  for < characteristic integer-part mantissa dec-negative
        is-nan is-inf exponent exp-negative
      > -> $method {
    my $v = $actions."$method"();
    note "  $method: $v", 
  }
#}}

  my $dec-sign-bit = $actions.dec-negative ?? 1 !! 0;
#  self.set-bits(127) if $dec-sign-bit;

  my $exp-sign-bit = $actions.exp-negative ?? 1 !! 0;

  if $actions.is-nan {
    # NaN: sign = 0 or 1, exponent = 11111111,
    # mantissa = arbitrary, but not only zeros
    self.set-bits(127) if $dec-sign-bit;
    self.set-bits( 119..126, 1, 0);
  }

  elsif $actions.is-inf {
    # Inf: sign = 0 or 1, exponent = 11111111
    # mantissa = 00000000000000000000000
    self.set-bits(127) if $dec-sign-bit;
    self.set-bits(119..126);
  }

  else {
    my Str $i = $actions.integer-part.Int.base(2);
    my Str $m = self.set-binary-mantissa('0.' ~ $actions.mantissa);
    $m ~~ s/ '0.' //;
#note "$?LINE $i.$m";
    my Int $bin-exponent;
    my Int $m-length;
    my Str $mantissa;

    # Test the integer part to modify the exponent.
    if $i ~~ m/^ 0 / {
      # When starting with '0', remove all zeros at start and calculate length.
      # length is negative exponent. The next '1' is removed.
      # This is the '1' before the comma.
      $m ~~ s/^ $<zeros> = 0+ //;
      $bin-exponent = - $/<zeros>.Str.chars - 1;
      $mantissa = $m.subst( '1', '', :1st);
    }

    else {
      # When starting with '1', the positive exponent is the number
      # of characters in the integer exponent minus one. The first '1'
      # is removed. This is the '1' before the comma.
      $bin-exponent = $actions.exponent.Int + $i.chars - 1;
      $mantissa = $i.subst( '1', '', :1st) ~ $m;
    }

    # Rounding needed? Mantissa <= 112 bits
    $m-length = $mantissa.chars;
#note "$?LINE binary exp: $bin-exponent, length: $m-length";
    if $m-length > C-MANT-BITS-D128 {
#$mantissa .= substr( 0, C-MANT-BITS-D128 + 3);
#note "$?LINE ", $mantissa.substr( C-MANT-BITS-D128, 1)  eq '1',
     "\n$mantissa";
      # check least significat bit + 1
      if $mantissa.substr( C-MANT-BITS-D128, 1)  eq '1' {
#note "$?LINE\n$mantissa";

        # Truncate to proper length
        $mantissa .= substr( 0, C-MANT-BITS-D128);
#note "$?LINE $mantissa.chars()\n$mantissa";
        # Check if least significant bit is a '1'.
        # Checked for different substution
        if $mantissa.substr( C-MANT-BITS-D128 - 1, 1)  eq '1' {
          $mantissa ~~ m/ 0 $<make-zero> = [1+] $/;
          my $zeros = $/<make-zero>.Str;
          $zeros ~~ s:g/ 1 /0/;
          $mantissa ~~ s/ 0 1+ $/1$zeros/;
        }

        else {
note "$?LINE\n$mantissa";
          $mantissa ~~ s/ 0 $/1/;
note "$?LINE\n$mantissa";
        }
      }

      else {
        $mantissa .= substr( 0, C-MANT-BITS-D128);
#note "$?LINE $mantissa.chars()";
      }
    }
note "$?LINE\n$mantissa";

    # The exponent is prefixed with '0's when too short
    my Str $exponent = (C-EXP-BIAS-D128 + $bin-exponent).base(2);
    my Int $fillup = C-EXP-BITS-D128 - $exponent.chars;
    if $fillup < 0 {
      # TODO: exponent too large
    }

    else {
      $exponent = '0' x $fillup ~ $exponent;
    }
    
    my Str $n = $dec-sign-bit ?? '1' !! '0';
    $n ~= $exponent;
    $n ~= $mantissa;
#note "$?LINE n: $n.chars(), $n\n$exponent $mantissa";
    self.set-bits-from-string( 0, $n);
  }
}

#-------------------------------------------------------------------------------
method reset-buf ( ) {
  $!d128 .= new( 0 xx C-BUFLEN-D128 );
}

#-------------------------------------------------------------------------------
method set-bits-from-string ( Int $start-pos is copy, Str $bit-positions ) {
  my @list = ();
  # First bit is most significant
  $start-pos = C-BITS-D128 - 1 - $start-pos if $!endian ~~ little-endian;
  for $bit-positions.comb -> $bit {
    @list.push: $start-pos if $bit eq '1';
    $start-pos += $!endian ~~ little-endian ?? -1 !! 1;
  }

#note "$?LINE list: @list.raku()";
  self.set-bits(@list);
}

#-------------------------------------------------------------------------------
method set-bits ( *@bit-positions ) {
  for @bit-positions -> $bit-pos {
    my Int() $byte-pos =
      $!endian ~~ little-endian ?? $bit-pos / 8 !! (127 - $bit-pos) / 8;

    my Int $offset = $bit-pos % 8;
#note "$?LINE $bit-pos, $offset, $byte-pos";
    $!d128[$byte-pos] +|= 1 +< $offset;
  }

#note "$?LINE ", $!d128>>.fmt('0x%0x');
}

#-------------------------------------------------------------------------------
method set-binary-mantissa ( FatRat() $number is copy --> Str ) {
#note "$?LINE $number";
  my Int $devider-count = 0;
  my FatRat $comparand; # = (2 ** $twos-exp).FatRat;
  my Str $result = '';
  my FatRat $zero .= new( 0, 1);

  # Take twice the number of bits possible. This is because the number
  # might be shifted up later to remove the leading zeros and
  # get a negative exponent.
  my constant $max-bits = 2 * C-MANT-BITS-D128;
  my constant $max-power = 2**($max-bits);

  for 2, 4, 8 ... $max-power -> $devider {
#note "$?LINE $devider-count, $devider, $number";
    last if ( ($number == $zero) or ($devider-count > $max-bits) );

    $comparand .= new( 1, $devider);
#note "$?LINE $comparand";
    if $number < $comparand {
      $result ~= '0';
    }

    else {
      $result ~= '1';
      $number -= $comparand;
    }

    $devider-count++;
#      $comparand = (2 ** $twos-exp).FatRat;
  }

  $result
}
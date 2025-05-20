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

#constant C--D128 = ;

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

  note "\n$?LINE $number";
  for < characteristic integer-part mantissa dec-negative
        is-nan is-inf exponent exp-negative
      > -> $method {
    my $v = $actions."$method"();
    note "  $method: $v", 
  }

  my $dec-sign-bit = $actions.dec-negative ?? 1 !! 0;
  self.set-bits(127) if $dec-sign-bit;

  my $exp-sign-bit = $actions.exp-negative ?? 1 !! 0;

  if $actions.is-nan {
    # NaN: sign = 0 or 1, exponent = 11111111,
    # mantissa = arbitrary, but not only zeros
    self.set-bits( 119..126, 1, 0);
  }

  elsif $actions.is-inf {
    # Inf: sign = 0 or 1, exponent = 11111111
    # mantissa = 00000000000000000000000
    self.set-bits(119..126);
  }

  else {
    my Str $i = $actions.integer-part.Int.base(2);
# not good enough
#    my Str $m = ('0.' ~ $actions.mantissa).FatRat.base(2);
    my Str $m = self.set-binary-mantissa('0.' ~ $actions.mantissa);
    $m ~~ s/ '0.' //;
note "$?LINE $i.$m";
    my Int $bin-exponent;
    my Int $m-length;
    my Str $result;

    # Test if exponent is negative
    if $i ~~ m/^ 0 / {
      $m ~~ s/^ $<zeros> = 0+ //;
      $bin-exponent = - $/<zeros>.Str.chars - 1;
      $result = $m.subst( '1', '', :1st);
    }

    else {
      $bin-exponent = $actions.exponent.Int + $i.chars - 1;
      $result = $i.subst( '1', '', :1st) ~ $m;
    }


    # Rounding needed? Mantissa ( without '1.' upfront) <= 112 bits
    $m-length = $result.chars - 2;
note "$?LINE $result, binary exp: $bin-exponent, length: $m-length";
    if $m-length > C-MANT-BITS-D128 {
      # check least significat bit + 1
      if $result.substr( C-MANT-BITS-D128 + 1, 1)  eq '1' {
note "$?LINE $result.chars(), $result.substr( C-MANT-BITS-D128 + 1, 1)";
        $result .= substr( 0, C-MANT-BITS-D128);
note "$?LINE $result.chars()\n$result";
        if $result.substr( C-MANT-BITS-D128, 1)  eq '1' {
          $result ~~ s/ 0 (1+) $/1$0/;
        }

        else {
          $result ~~ s/ 0 $/1/;
        }
#        my $c = $m-length;
#        while $result.substr( $c, 1)  eq '1' {
#          $result.subst( $c, 1, '0');
#          $c--;
#        }

#        $result.subst( $c, 1, '1');
      }

      else {
        $result .= substr( 0, C-MANT-BITS-D128);
note "$?LINE $result.chars()";
      }

      
    }
note "$?LINE $result";

    my $exponent = C-EXP-BIAS-D128 + $bin-exponent;

  }
}

#-------------------------------------------------------------------------------
method reset-buf( ) {
  $!d128 .= new( 0 xx C-BUFLEN-D128 );
}

#-------------------------------------------------------------------------------
method set-bits( *@bit-positions ) {
  for @bit-positions -> $bit-pos {
    my Int() $byte-pos =
      $!endian ~~ little-endian ?? $bit-pos / 8 !! (127 - $bit-pos) / 8;

    my Int $offset = $bit-pos % 8;
#note "$?LINE $bit-pos, $offset, $byte-pos";
    $!d128[$byte-pos] +|= 1 +< $offset;
  }

note "$?LINE ", $!d128>>.fmt('%0x');
}

#-------------------------------------------------------------------------------
method set-binary-mantissa ( FatRat() $number is copy --> Str ) {
#note "$?LINE $number";
  my Int $devider-count = 0;
  my FatRat $comparand; # = (2 ** $twos-exp).FatRat;
  my Str $result = '';
  my FatRat $zero .= new( 0, 1);
  my constant $max-bits = 2 * C-MANT-BITS-D128;
  my constant $max-power = 2**($max-bits);

  # Take twice the number of bits possible. This is because number is
  # shifted up later to have a 1 before the point.
  for 2, 4, 8 ... $max-power -> $devider {
#note "$?LINE $devider-count, $devider, $number";
    last if ( ($number ≤ $zero) or ($devider-count > $max-bits) );

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
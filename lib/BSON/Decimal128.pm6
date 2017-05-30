use v6;

# Decimal Encoding Specification at http://speleotrove.com/decimal/dbspec.html
# Densely Packed Decimal encoding at http://speleotrove.com/decimal/DPDecimal.htmlhttp://speleotrove.com/decimal/DPDecimal.html
# Wiki https://en.wikipedia.org/wiki/Binary-coded_decimal
#------------------------------------------------------------------------------
unit package BSON:auth<github:MARTIMM>;

#------------------------------------------------------------------------------
# https://en.wikipedia.org/wiki/Decimal128_floating-point_format
# http://speleotrove.com/decimal/dbspec.html
# https://github.com/mongodb/specifications/blob/master/source/bson-decimal128/decimal128.rst#terminology
#------------------------------------------------------------------------------
class Decimal128 {

  constant C-BIAS-D128 = 6176;
  constant C-EMAX-D128 = 6144;
  constant C-EMIN-D128 = -6143;
  constant C-ZERO-ORD = '0'.ord;

  #----------------------------------------------------------------------------
  has Buf $!internal .= new( 0x00 xx 16 );
  has FatRat $!number;
  has Str $!string;
  has Bool $!is-inf;
  has Bool $!is-nan;

  has Buf $!bcd8;
  has Buf $!dpd;

  #----------------------------------------------------------------------------
  # FatRat initialization
  multi submethod new ( $n, $d ) {
    self.bless(:number(FatRat.new( $n, $d)));
  }

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # other specialized initializations
  multi submethod new ( |c ) {
    self.bless(|c);
  }

  #----------------------------------------------------------------------------
  # FatRat initialization
  multi submethod BUILD ( FatRat:D :$!number! ) {  }

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # init using Rat
  multi submethod BUILD ( Rat:D :$rat! ) {
    $!is-inf = $!is-nan = False;
    $!number = $rat.FatRat;
  }

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # init using Num. it is possible to define Inf and NaN with Num.
  multi submethod BUILD ( Num:D :$num! ) {

    $!is-inf = $!is-nan = False;
    if $num ~~ any( Inf, -Inf) {
      $!is-inf = True;
      $!number .= new( $num.sign, 1);
    }

    elsif $num ~~ NaN {
      $!is-nan = True;
    }

    else {
      $!number = $num.FatRat;
    }
  }

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # init using string
  multi submethod BUILD ( Str:D :$str! ) {
    $!is-inf = $!is-nan = False;
    $!number = $str.FatRat;
  }

  #----------------------------------------------------------------------------
  # return string representation for string concatenation
  method Str ( --> Str ) {
    if self.defined and ?$!number {
      $!number.Str;
    }

    else {
      NaN.Str;
    }
  }

  #----------------------------------------------------------------------------
  # return string representation for string concatenation
  method Bool ( --> Bool ) {
    self.defined and ? $!number.numerator;
  }

  #----------------------------------------------------------------------------
  # return a number when requeste for calculations
  method Numeric ( --> Numeric ) {
    $!number;
  }

  #----------------------------------------------------------------------------
  # encode to BSON binary
  multi method encode ( --> Buf ) {

    # 34 digits precision of which one digit of 4 bits is merged into the
    # space of 3 bits and placed in the combination field together with 2 bits
    # from the exponent. Thus;

    # Combination
    # field (5 bits) 	 Type 	    Exponent       Coefficient
    #               	            MSBs (2 bits)  MSD (4 bits)
    # a b c d e 	     Finite 	  a b 	         0 c d e
    # 1 1 c d e 	     Finite 	  c d 	         1 0 0 e
    # 1 1 1 1 0 	     Infinity 	- - 	         - - - -
    # 1 1 1 1 1        NaN        - - 	         - - - -

    # For the rest of the precision 33 digits as DPD 33/3 * 10 = 110 bits
    # Leaves us an exponent of 128 - 1(sign) - 5(combination) - 110 = 12 bits
    # With 2 bits exponent in the combination field it gives a total of 14 bits.

    # Test for special cases NaN and Inf
    if $!is-nan {
      # NaN, sign bit set to 0 but ignored like the rest of the bytes
      $!internal .= new( 0x7c, 0x00 xx 15);
    }

    elsif $!is-inf {
      my Int $s = $!number.sign;
      if $s == 1 {
        # +Inf
        $!internal .= new( 0x78, 0x00 xx 15);
      }

      else {
        # -Inf
        $!internal .= new( 0xf8, 0x00 xx 15);
      }
    }

    # all other finite cases
    else {
      # store number an get string representation then remove trailing spaces
      $!string = $!number.fmt('%34.34f');
      $!string ~~ s/ '0'+ $ // if $!string.index('.');

      # reset any previous values
      $!internal .= new(0x00 xx 16);

      # set sign bit
      $!internal[15] = 0x80 if $!number.sign == -1;

note "string: $!string";
      my Int $index = $!string.index('.');
      my Int $exponent;
      if $!string ~~ m/^ '0' / {
        $exponent = 0;
      }

      else {
        # when no dot is found the exponent is not changed.
        $exponent = $index // $exponent;
      }
note "ex 0: $exponent";

      my Int $adj-exponent;
      my Str $coefficient = $!string;
      if ? $index {
        $adj-exponent = $!string.chars - $index - 1;
        $coefficient ~~ s/'.'//;
      }

      else {
        $adj-exponent = $exponent;
      }

      $adj-exponent += C-BIAS-D128;

note "coeff 1: $coefficient";
note "ex 1: $adj-exponent";

      # Check number of characters in coefficient
      die "coeff too big" if $coefficient.chars > 34;

      # Check for exponent
#      die "exp too large" if $adj-exponent > C-EMAX-D128;
#      die "exp too small" if $adj-exponent > C-EMIN-D128;


      # Get the coefficient. The MSByte is at the end of the array
      self.bcd2dpd(self.bcd8($coefficient));

      # Copy 13 bytes and 6 bits into the result, a total of 110 bits
      for ^14 -> $i {
        $!internal[$i] = $!dpd[$i];
      }

      # Following is needed because the 2 bits map to a part of the last digit
      # which must go to the combination bits. on these 2 bits, the exponent
      # must start.
      $!internal[13] +&= 0x3f;

      # Get the last digit and copy to combination bits. Position the bits to
      # the spot where it should come in the combination field.
      my Int $c = $!dpd[14] +& 0xc0;
      $c +>= 4;
      $c +|= (($!dpd[15] +& 0x03) +< 4);

      # If digit larger than 7 the bit at 0x20 is set. if so, bit at 0x40
      # must be set too.
      $c +|= 0x40 if $c +& 0x20;


      # Get the exponent and copy 2 MSBits of it to the combination field
      my $two-msb = $adj-exponent +& 0x3000;
      if $c +& 0x20 {
        $c +|= ($two-msb +> 1);
      }

      else {
        $c +|= ($two-msb +< 1);
      }

      # copy component into the result
      $!internal[15] +|= $c;

      # copy the rest of the exponent
      # next two MSbits of exponent in first byte, then a byte, then last 2bits
      $!internal[15] +|= (($adj-exponent +& 0x0c00) +> 8); # ?
      $!internal[14] +|= (($adj-exponent +& 0x03fc) +> 2);
      $!internal[13] +|= (($adj-exponent +& 0x0003) +< 5); # ?

note "D128:\n", ($!internal>>.fmt(' %08b')).join('');
note "D128:\n", $!internal;
    }

    $!internal;
  }

  #----------------------------------------------------------------------------
  # decode from BSON binary
  method decode (
    Buf:D $b,
    Int:D $index is copy,
    --> BSON::Decimal128
  ) {

  }

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # compress BCD to Densely Packed Decimal
  method bcd2dpd( Buf $bcd8? --> Buf ) {

    $!bcd8 = $bcd8 // $!bcd8;
    die '8bit BCD buffer not defined' unless ? $!bcd8;

    # init result bits array
    my @dpd = ();

    # match to multple of 3 digits.
    while ! ($!bcd8.elems %% 3) {
      $!bcd8.push(0);
    }

    # Pack every 3 nibles (each in a byte) into 10 bits
    for @$!bcd8 -> $b1, $b2, $b3 {

      my @bit-array = ();
      @bit-array.push( |map {$_ - C-ZERO-ORD}, $b1.fmt('%04b').ords.reverse );
      @bit-array.push( |map {$_ - C-ZERO-ORD}, $b2.fmt('%04b').ords.reverse );
      @bit-array.push( |map {$_ - C-ZERO-ORD}, $b3.fmt('%04b').ords.reverse );
note "bit array $b1, $b2, $b3 for dpd:    ", @bit-array;

      my Int $msb-bits = 0;
      my @dense-array = ();

      $msb-bits = (@bit-array[3] +< 2) +|         # $b1 sign
                  (@bit-array[7] +< 1) +|         # $b2 sign
                  (@bit-array[11]);               # $b3 sign
note "msb-bits for dpd: ", $msb-bits.fmt('%03b');

      # Compression: (abcd)(efgh)(ijkm) becomes (pqr)(stu)(v)(wxy)
      given $msb-bits {

        # 000 => bcd fgh 0 jkm 	All digits are small
        when 0b000 {
          @dense-array = |@bit-array[0..2], 0, |@bit-array[4..6],
                         |@bit-array[8..10];
        }

        # 001 => bcd fgh 1 00m   Right digit is large [this keeps 0-9 unchanged]
        # Same as for 0b000
        when 0b001 {
          @dense-array = |@bit-array[1..3], |@bit-array[5..11];
        }

        # 010 => bcd jkh 1 01m   Middle digit is large
        when 0b010 {
          @dense-array = |@bit-array[1..3], |@bit-array[9..10], @bit-array[7],
                         1, 0, 1, @bit-array[11];
        }

        # 011 => bcd 10h 1 11m   Left digit is small [M & R are large]
        when 0b011 {
          @dense-array = |@bit-array[1..3], 1, 0, @bit-array[7],
                         1, 1, 1, @bit-array[11];
        }

        # 100 => jkd fgh 1 10m   Left digit is large
        when 0b100 {
          @dense-array = @bit-array[11], 0, 1, 1, |@bit-array[4..6],
          @bit-array[8], |@bit-array[1,2];
        }

        # 101 => fgd 01h 1 11m   Middle digit is small [L & R are large]
        when 0b101 {
          @dense-array = |@bit-array[5..6], @bit-array[3],
                         0, 1, @bit-array[7], 1, 1, 1, @bit-array[11];
        }

        # 110 => jkd 00h 1 11m   Right digit is small [L & M are large]
        when 0b110 {
          @dense-array = |@bit-array[9..10], @bit-array[3], 0, 0,
                         @bit-array[7], 1, 1, 1, @bit-array[11];
        }

        # 111 => 00d 11h 1 11m   All digits are large; two bits are unused
        when 0b111 {
          @dense-array = 0, 0, @bit-array[3], 1, 1, @bit-array[7],
                         1, 1, 1, @bit-array[11];
        }
      }

note 'dense array:', ' ' x 18, @dense-array;
      @dpd.push(|@dense-array);
    }
note 'dense array result: ', ' ' x 10, @dpd;

    # make multiple of 8 bits to fit bytes
    @dpd = @dpd; #.reverse;
    while ! (@dpd.elems %% 8) {
#      @dpd.unshift(0);
      @dpd.push(0);
    }
note 'corrected dense array result: ', @dpd; #, ' (reversed)';

    $!dpd = Buf.new;
    for @dpd -> $b0, $b1, $b2, $b3, $b4, $b5, $b6, $b7 {
      $!dpd.push(:2(( $b0, $b1, $b2, $b3, $b4, $b5, $b6, $b7).reverse.join('')));
    }

note 'dpd: ', $!dpd;
    $!dpd;
  }

#`{{
  #----------------------------------------------------------------------------
  multi method bcd ( Int $n --> Buf ) {
    self.bcd($n.Str);
  }

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Little endian of a BSD representation (BSON likes litle endian)
  multi method bcd ( Str $sn --> Buf ) {

    my Buf $bcd .= new();

    my @nbrs = map {$_ - C-ZERO-ORD}, $sn.ords.reverse;
    @nbrs.push(0) if @nbrs.elems +& 0x01;

    for @nbrs -> $digit1, $digit2 {
      my Int $byte = 0;
      $byte +|= $digit1;
      $byte +|= ($digit2 +< 4) if $digit2.defined;
      $bcd.push($byte);
    }

    $bcd;
  }
}}

  #----------------------------------------------------------------------------
  multi method bcd8 ( Int $n --> Buf ) {
    self.bcd8($n.Str);
  }

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Little endian of a BSD representation (BSON likes litle endian).
  # One digit per byte. This is easier to process later on
  multi method bcd8 ( Str $sn --> Buf ) {
#note "string for bcd8: $sn";

    $!bcd8 .= new();

    my @nbrs = map {$_ - C-ZERO-ORD}, $sn.ords.reverse;
    for @nbrs -> $digit {
      $!bcd8.push($digit);
    }

#note "bcd8: ", $!bcd8;
    $!bcd8;
  }
}

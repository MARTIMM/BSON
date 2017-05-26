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
  constant C-ZERO-ORD = '0'.ord;

  #----------------------------------------------------------------------------
  has Buf $!internal .= new( 16 xx 0 );
  has FatRat $!number;
  has Str $!string;

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
  multi submethod BUILD ( FatRat:D :$!number! ) {
    $!string = $!number.fmt('%34.34f');
  }

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # init using Rat
  multi submethod BUILD ( Rat:D :$rat! ) {
    $!number = $rat.FatRat;
    $!string = $!number.fmt('%34.34f');
  }

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # init using Num. it is possible to define Inf and NaN with Num.
  multi submethod BUILD ( Num:D :$num! ) {
    $!number = $num.FatRat;
    $!string = $!number.fmt('%34.34f');
  }

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # init using string
  multi submethod BUILD ( Str:D :$str! ) {
    $!number = $str.FatRat;
    $!string = $str;
  }

  #----------------------------------------------------------------------------
  # return string representation for string concatenation
  method Str ( --> Str ) {
    $!string // NaN.Str;
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

    my Buf $exponent;
    my Buf $coefficient;
    my Buf $combination;

    my Bool $s = $!number.sign;
    my Int $e = 0;

    my $dot = $!number.index('.');
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

    $!bcd8 //= $bcd8;
    die '8bit BCD buffer not defined' unless ? $!bcd8;

    my @dpd = ();

    while ! ($!bcd8.elems %% 3) {
      $!bcd8.push(0);
    }

    # Pack every 3 nibles into 10 bits
    for @$!bcd8 -> $b1, $b2, $b3 {

      my @bit-array = ();
      @bit-array.push( |map {$_ - C-ZERO-ORD}, $b1.fmt('%04b').ords );
      @bit-array.push( |map {$_ - C-ZERO-ORD}, $b2.fmt('%04b').ords );
      @bit-array.push( |map {$_ - C-ZERO-ORD}, $b3.fmt('%04b').ords );
#note 'bit array:   ', @bit-array;

      my Int $msb-bits = 0;
      my @dense-array = ();

      $msb-bits = (@bit-array[0] +< 2) +|
                  (@bit-array[4] +< 1) +|
                  (@bit-array[8]);
#note "msb-bits: ", $msb-bits.fmt('%03b');

      # Compression: (abcd)(efgh)(ijkm) becomes (pqr)(stu)(v)(wxy)
      given $msb-bits {

        # 000 => bcd fgh 0 jkm 	All digits are small
        when 0b000 {
          @dense-array = |@bit-array[1..3], |@bit-array[5..11];
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
          @dense-array = |@bit-array[9..10], @bit-array[3], |@bit-array[5..7],
                         1, 1, 0, @bit-array[11];
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

#note 'dense array: ', @dense-array;
      @dpd.push(|@dense-array);
    }
#note 'dense array result: ', @dpd;

    while ! (@dpd.elems %% 8) {
      @dpd.unshift(0);
    }
#note 'corrected dense array result: ', @dpd;

    $!dpd = Buf.new;
    for @dpd -> $b0, $b1, $b2, $b3, $b4, $b5, $b6, $b7 {
      $!dpd.push(:2(( $b0, $b1, $b2, $b3, $b4, $b5, $b6, $b7).join('')));
    }

#note 'dpd: ', $!dpd;
    $!dpd;
  }

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

  #----------------------------------------------------------------------------
  multi method bcd8 ( Int $n --> Buf ) {
    self.bcd8($n.Str);
  }

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Little endian of a BSD representation (BSON likes litle endian)
  multi method bcd8 ( Str $sn --> Buf ) {

    $!bcd8 .= new();

    my @nbrs = map {$_ - C-ZERO-ORD}, $sn.ords.reverse;
    for @nbrs -> $digit {
      $!bcd8.push($digit);
    }

    $!bcd8;
  }
}

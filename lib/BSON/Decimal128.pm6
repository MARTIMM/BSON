use v6;

#------------------------------------------------------------------------------
unit package BSON:auth<github:MARTIMM>;

#------------------------------------------------------------------------------
# https://en.wikipedia.org/wiki/Decimal128_floating-point_format
# http://speleotrove.com/decimal/dbspec.html
# https://github.com/mongodb/specifications/blob/master/source/bson-decimal128/decimal128.rst#terminology
#------------------------------------------------------------------------------
class Decimal128 {

  #----------------------------------------------------------------------------
  has Buf $!internal .= new( 16 xx 0 );
  has FatRat $!number;

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
  multi submethod BUILD ( FatRat:D :$!number! ) { }

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # init using Rat
  multi submethod BUILD ( Rat:D :$rat! ) {
    $!number = $rat.FatRat;
  }

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # init using Num. it is possible to define Inf and NaN with Num.
  multi submethod BUILD ( Num:D :$num! ) {
    $!number = $num.FatRat;
  }

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # init using string
  multi submethod BUILD ( Str:D :$str! ) {
    $!number = $str.FatRat;
  }

  #----------------------------------------------------------------------------
  # return string representation for string concatenation
  method Str ( --> Str ) {
    $!number.Str;
  }

  #----------------------------------------------------------------------------
  # return a number when requeste for calculations
  method Numeric ( --> Numeric ) {
    $!number;
  }

  #----------------------------------------------------------------------------
  # encode to BSON binary
  multi method encode ( --> Buf ) {

  }

  #----------------------------------------------------------------------------
  # decode from BSON binary
  method decode (
    Buf:D $b,
    Int:D $index is copy,
    --> BSON::Decimal128
  ) {

  }
}

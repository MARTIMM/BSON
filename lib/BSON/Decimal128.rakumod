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
constant C-EXPCONT-D128 = 12;
constant C-TOTEXP-D128 = 14;
constant C-COEFCONT-D128 = 110;
constant C-TOTCOEFDIG-D128 = 34;
constant C-EMAX-D128 = 6144;
constant C-EMIN-D128 = -6143;
constant C-ELIMIT-D128 = 12287;
constant C-BIAS-D128 = 6176;

#constant C--D128 = ;

#-------------------------------------------------------------------------------
enum endianness <little-endian big-endian system-endian>;

our $endian = little-endian;
has Buf $.d128;

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
  my BSON::Decimal128::Actions $actions .= new;
  my $matchObject = Decimal-Grammar.parse( $number, :$actions);

  note "\n$?LINE $number";
  for < characteristic mantissa dec-negative
        is-nan is-inf exponent exp-negative
      > -> $method {
    my $v = $actions."$method"();
    note "  $method: $v", 
  }
}

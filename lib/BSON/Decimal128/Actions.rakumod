use v6;

#-------------------------------------------------------------------------------
unit class BSON::Decimal128::Actions:auth<github:MARTIM>;

has Str $.characteristic;
has Str $.mantissa;
has Str $.integer-part;
has Bool $.dec-negative;
has Bool $.is-nan;
has Bool $.is-inf;

has Str $.exponent;
has Bool $.exp-negative;

#-------------------------------------------------------------------------------
method initialize ( Match $m ) {
  $!dec-negative = False;
  $!characteristic = '';
  $!mantissa = '';
  $!is-nan = False;
  $!is-inf = False;
  $!integer-part = '';

  $!exp-negative = False;
  $!exponent = '';
}

#-------------------------------------------------------------------------------
method numeric-string ( Match $m ) {

  $!dec-negative = ~($m<sign> // '') eq '-';
  $!characteristic = ~($m<numeric-value><decimal-part><characteristic> // '');
  $!integer-part = ~($m<numeric-value><decimal-part><integer-part> // '');
  $!mantissa = ~($m<numeric-value><decimal-part><mantissa> // '');
  $!is-nan = $m<nan>.defined;
  $!is-inf = $m<numeric-value><infinity>.defined;

  $!exp-negative = ~($m<numeric-value><exponent-part><sign> // '') eq '-';
  $!exponent = ~($m<numeric-value><exponent-part><exponent> // '0');

  # remove leading zeros from characteristic
  $!characteristic ~~ s/^ '0'+ //;

  # remove trailing zeros from mantissa
  $!mantissa ~~ s/ '0'+ $//;
}

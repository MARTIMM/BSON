use v6;

#use BSON::Decimal128;

#-------------------------------------------------------------------------------
unit package BSON::Decimal128::Grammar:auth<github:MARTIM>;


#-------------------------------------------------------------------------------
#`{{
  Grammar taken from https://github.com/mongodb/specifications/blob/master/source/bson-decimal128/decimal128.md
  sign           ::=  ’+’ | ’-’
  digit          ::=  ’0’ | ’1’ | ’2’ | ’3’ | ’4’ | ’5’ | ’6’ | ’7’ |
  ’8’ | ’9’
  indicator      ::=  ’e’ | ’E’
  digits         ::=  digit [digit]...
  decimal-part   ::=  digits ’.’ [digits] | [’.’] digits
  exponent-part  ::=  indicator [sign] digits
  infinity       ::=  ’Infinity’ | ’Inf’
  nan            ::=  ’NaN’
  numeric-value  ::=  decimal-part [exponent-part] | infinity
  numeric-string ::=  [sign] numeric-value | [sign] nan
}}

grammar Decimal-Grammar is export {
  rule TOP { <.initialize> <numeric-string> }
  rule initialize { <?> }

  token nsign { $<nsign> = <[+-]> }
  token esign { $<esign> = <[+-]> }
  token indicator { :i e }
  token digits { \d+ }
  token decimal-part {
    $<characteristic> = [ <.digits> '.' $<mantissa> = <.digits>? |
                          '.' $<mantissa> = <.digits>
                        ] |
    $<characteristic> = <.digits>
  }

  token exponent-part { <.indicator> <esign>? $<exponent> = <.digits> }
  token infinity { :i ['infinity' | 'Inf' ] }
  token nan { :i 'NaN' }
  token numeric-value { <decimal-part> <exponent-part>? | <infinity> }
  token numeric-string { <nsign>? <numeric-value> | <nsign>? <nan> }
}

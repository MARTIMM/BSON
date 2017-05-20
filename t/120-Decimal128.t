use v6;
use Test;

use BSON::Decimal128;

#-------------------------------------------------------------------------------
subtest 'encode decimal128', {
  my BSON::Decimal128 $d128 .= new(:number(10.456));
  isa-ok $d128, BSON::Decimal128;

}

#-------------------------------------------------------------------------------
done-testing

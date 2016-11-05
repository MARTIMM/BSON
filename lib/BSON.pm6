use v6.c;

#-----------------------------------------------------------------------------
class X::BSON::Parse-objectid is Exception {
  has $.operation;                      # Operation method
  has $.error;                          # Parse error

  method message () {
    return "\n$!operation\() error: $!error\n";
  }
}

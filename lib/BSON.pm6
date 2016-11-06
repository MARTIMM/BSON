use v6.c;

#-----------------------------------------------------------------------------
class X::BSON::Parse-objectid is Exception {
  has $.operation;                      # Operation method
  has $.error;                          # Parse error

  method message () {
    return "\n$!operation\() error: $!error\n";
  }
}

#-------------------------------------------------------------------------------
class X::BSON::Parse-document is Exception {
  has $.operation;                      # Operation method
  has $.error;                          # Parse error

  method message () {
    return "\n$!operation error: $!error\n";
  }
}

#-------------------------------------------------------------------------------
class X::BSON::NYS is Exception {
  has $.operation;                      # Operation encode, decode
  has $.type;                           # Type to encode/decode

  method message () {
    return "\n$!operation error: BSON type '$!type' is not (yet) supported\n";
  }
}

#-------------------------------------------------------------------------------
class X::BSON::DEPRECATED is Exception {
  has $.operation;                      # Operation encode, decode
  has $.type;                           # Type to encode/decode

  method message () {
    return "\n$!operation error: BSON type '$!type' is deprecated\n";
  }
}



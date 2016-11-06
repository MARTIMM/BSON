use v6.c;

#-----------------------------------------------------------------------------
class X::BSON::Parse-objectid is Exception {

  # No string types used because there can be lists of strings too
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
class X::BSON::Deprecated is Exception {
  has $.operation;                      # Operation encode, decode
  has $.type;                           # Type to encode/decode
  has Int $.subtype;                    # Subtype of type

  method message () {
    my Str $m;
    if ?$!subtype {
      $m = "subtype '$!subtype' of BSON '$!type'";
    }

    else {
      $m = "BSON type '$!type'"
    }

    return "\n$!operation error: $m is deprecated\n";
  }
}



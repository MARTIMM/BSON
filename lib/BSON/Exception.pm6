use v6;

# Basic BSON encoding and decoding tools. These exported subs process
# strings and integers.

package BSON {

  class X::BSON::Parse is Exception {
    has $.operation;                      # Operation method
    has $.error;                          # Parse error

    method message () {
      return "\n$!operation\() error: $!error\n";
    }
  }

}

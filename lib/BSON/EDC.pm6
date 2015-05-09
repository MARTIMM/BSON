use v6;
use BSON::D;
use BSON::EDC-Tools;

#-------------------------------------------------------------------------------
#
class X::BSON::Encodable is Exception {
  has $.operation;                      # Operation encode, decode or other
  has $.type;                           # Type to handle
  has $.emsg;                           # Extra message


  method message () {
      return "\n$!operation\() on $!type error: $!emsg";
  }
}

#-------------------------------------------------------------------------------
# This role implements BSON serialization functions. To provide full encoding
# of a type more information must be stored. This class must represent
# a document such as { key => SomeType.new(...) }. Therefore it needs to store
# the key name and the data representing the class.
# Furthermore it needs a code for the specific BSON type.
# 
#
# Role to encode to and/or decode from a BSON representation.
#
package BSON {
  class Encodable is BSON::Encodable-Tools {

    constant $BSON-DOUBLE       = 0x01;
    constant $BSON-DOCUMENT     = 0x03;

    # Visible in all objects of this class
    #
    my Int $index = 0;

    #---------------------------------------------------------------------------
    #
    method encode ( Hash $document --> Buf ) {

      my Int $doc-length = 0;
      my Buf $stream-part;
      my Buf $stream = Buf.new();

      for $document.keys -> $var-name {
        my $data = $document{$var-name};
        given $data {
          when Num {
            my $promoted-self = self.clone;
            $promoted-self does BSON::Double;

            $stream-part = [~] Buf.new($BSON-DOUBLE),
                               self.enc_cstring($var-name),
                               $promoted-self.encode_obj($data);
            $stream ~= $stream-part;
          }

          when Hash {
            $stream-part = [~] Buf.new($BSON-DOCUMENT),
                               self.enc_cstring($var-name),
                               self.encode($data);
            $stream ~= $stream-part;
          }
        }
      }

      return [~] self.enc_int32($stream.elems + 5), $stream, Buf.new(0x00);
    }

    #---------------------------------------------------------------------------
    # This one is used to start decode process
    #
    multi method decode ( Buf $stream --> Hash ) {
      $index = 0;
#say "MM D 0: index: $index";
      return self!decode_document($stream.list);
    }

    # This one is used to recursively decode sub documents
    #
    multi method decode ( Array $stream --> Hash ) {
#say "MM D 1: index: $index";
      return self!decode_document($stream);
    }

    method !decode_document ( Array $encoded-document --> Hash ) {

      my Hash $document;
#say "BC 0: index: $index";
      my Int $doc-length = self.dec_int32( $encoded-document, $index);
#say "DL: $doc-length";

      my Int $bson_code = $encoded-document[$index++];
      while $bson_code {
#say "BC 1: $bson_code, index: $index";
        my Str $key_name = self.dec_cstring( $encoded-document, $index);

        given $bson_code {
          when $BSON-DOUBLE {
            my $promoted-self = self.clone;
            $promoted-self does BSON::Double;
#say "BC 1a: index: $index";
            $document{$key_name} = $promoted-self.decode_obj( $encoded-document,
                                                              $index
                                                            );
#say "BC 1b: index: $index";
          }

          when $BSON-DOCUMENT {
#say "BC 1c: index: $index";
            $document{$key_name} = self.decode($encoded-document);
#say "BC 1d: index: $index";
          }

          default {
            say "What?!: $bson_code";
          }
        }

        $bson_code = $encoded-document[$index++];
#say "BC 1e: $bson_code, index: $index";
      }

#say "BC 2a: index: $index";
      return $document;
    }
  }
}

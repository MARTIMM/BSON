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

    constant $BSON-DOUBLE = 0x01;

    constant $BSON-DOCUMENT = 0x03;

#    has Int $!enc-doc-idx;

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
    #
    multi method decode ( Buf $stream --> Hash ) {
      return self!decode_document($stream.list);
    }
    
    multi method decode ( Array $stream is rw --> Hash ) {
      return self!decode_document($stream);
    }
    
    method !decode_document ( Array $encoded-document is rw --> Hash ) {
#      $!enc-doc-idx = 0;
#      given $encoded-document[$!enc-doc-idx] {

      my Hash $document;
      my Int $doc-length = self.dec_int32($encoded-document);
#say "DL: $doc-length";

      my $bson_code = $encoded-document.shift;
      while $bson_code {
#say "BC: $bson_code";
        my $key_name = self.dec_cstring($encoded-document);

        given $bson_code {
          when $BSON-DOUBLE {
            my $promoted-self = self.clone;
            $promoted-self does BSON::Double;
            $document{$key_name} = $promoted-self.decode_obj($encoded-document);
          }
          
          when $BSON-DOCUMENT {
            $document{$key_name} = self.decode($encoded-document);
          }

          default {
            say "What?!: $bson_code";
          }
        }
      
        $bson_code = $encoded-document.shift;
      }

      return $document;
    }
  }
}

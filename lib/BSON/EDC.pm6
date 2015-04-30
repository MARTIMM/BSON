use v6;
use BSON::D;
use BSON::EDC-Tools;

class X::BSON::Encodable is Exception {
  has $.operation;                      # Operation encode, decode or other
  has $.type;                           # Type to handle
  has $.emsg;                           # Extra message

  method message () {
      return "\n$!operation\() on $!type error: $!emsg";
  }
}

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

    has Int $.bson_code;
    has Str $.key_name;
    has Any $.key_data is rw;
    has Int $!enc-doc-idx;

#    submethod BUILD ( Str :$key_name, Num :$key_data ) {
#      self.init( :bson_code($BSON-DOUBLE), :$key_name, :$key_data);
#    }

    multi method init ( Hash $document --> Buf ) {

      my Int $doc-length = 0;
      my Buf $stream = Buf.new();
      my Buf $data;
      
      for $document.keys -> $var-name {
        my $data = $document{$var-name};
        given $data {
          when Num {
            
            my $promoted-self = self.clone;
            $promoted-self does BSON::Double;

            $data = [~] Buf.new($BSON-DOUBLE),
                        self.enc_e_name($var-name),
                        $promoted-self.encode_obj($data);

            $stream ~= $data;
          }
        }
      }

      return [~] self.enc_int32($stream.elems + 5), $stream, Buf.new(0x00);
    }

    multi method init ( Buf $stream --> Hash ) {
#      $!enc-doc-idx = 0;
#      given $encoded-document[$!enc-doc-idx] {

      my Hash $document;
      my Array $encoded-document = $stream.list;
      my Int $doc-length = self.dec_int32($encoded-document);

      self.decode_code($encoded-document);
      self.decode_key($encoded-document);

      given $!bson_code {
        when $BSON-DOUBLE {
          my $promoted-self = self.clone;
          $promoted-self does BSON::Double;

          $!key_data = $promoted-self.decode_obj($encoded-document);
          
          $document{$!key_name} = $!key_data;
        }

        default {
          say "What?!: $!bson_code";
        }
      }
    
      return $document;
    }

    #-----------------------------------------------------------------------------
    # Basic encoding functions
    #
    # Encode code, key and data
    #
    method encode( --> Buf ) {
      return [~] self.encode_code,
                 self.encode_key,
                 self.encode_obj($!key_data);
    }

    # Abstract method to encode internal data to a binary buffer
    #
#    method encode_obj( $data --> Buf ) { ... }

    # Encode bson code
    #
    method encode_code ( --> Buf ) {
      return Buf.new($!bson_code);
    }

    # Encode key
    #
    method encode_key ( --> Buf ) {

      return self.enc_e_name($!key_name);
    }

    #-----------------------------------------------------------------------------
    # Basic decoding functions
    #
    # Decode code, key and data
    #
    method decode( Array $b ) {
      self.decode_code($b);
      self.decode_key($b);
      $!key_data = self.decode_obj($b);
    }

    # Abstract method to decode a binary buffer to internal data.
    #
#    method decode_obj( Array $b --> Any ) { ... }

    # The code must be the first octet in the buffer
    #
    method decode_code ( Array $b ) {

      $!bson_code = $b.shift;
      # Test proper range...
    }

    method decode_key ( Array $b ) {

  #    $!key_name = self.dec_e_name( $b );
      $!key_name = self.dec_cstring( $b );
    }
  }
}

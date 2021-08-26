use v6.d;

use BSON;
use BSON::ObjectId;
use BSON::Binary;
use BSON::Decimal128;
use BSON::Javascript;
use BSON::Regex;

use BSON::Document;
use BSON::Ordered;

#------------------------------------------------------------------------------
unit class BSON::Encode:auth<github:MARTIMM>:ver<0.2.0>;

has UInt $!index = 0;
has Buf @!encoded-entries;

#----------------------------------------------------------------------------
# Called from user to get a complete encoded document or by a request
# from an encoding Document to encode a subdocument or array.
method encode ( BSON::Document $document --> Buf ) {

  my $idx = 0;
  for $document.keys -> $k {
    @!encoded-entries[$idx] = self!encode-element( $k, $document{$k});
    $idx++;
  }

  # if there are entries
  my Buf $encoded-document = Buf.new;
  for @!encoded-entries -> $e {
    $encoded-document ~= $e;
  }

  # encode size: number of elems + null byte at the end
#  my Buf $b = [~] encode-int32($encoded-document.elems + 5),
  my Buf $b = [~] Buf.new.write-int32(
    0, $encoded-document.elems + 5, LittleEndian
  ), $encoded-document, Buf.new(0x00);

  $b
}

#----------------------------------------------------------------------------
# Encode a key value pair. Called from the insertion methods above when a
# key value pair is inserted.
#
# element ::= type-code e_name some-encoding
#
method !encode-element ( Str $key, $value --> Buf ) {

  my Buf $b;

  given $value {

    when Num {
      # Double precision
      # "\x01" e_name Num
      #
      $b = [~] Buf.new(BSON::C-DOUBLE),
               encode-e-name($key),
#               encode-double($value);
               Buf.new.write-num64( 0, $value, LittleEndian);
    }

    when Str {
      # UTF-8 string
      # "\x02" e_name string
      #
      $b = [~] Buf.new(BSON::C-STRING),
               encode-e-name($key),
               encode-string($value);
    }

    when BSON::Ordered {
      # Embedded document
      # "\x03" e_name document

      my BSON::Document $d .= new: (
        (for $value.kv -> $ka, $va { "$ka" => $va })
      );

      my BSON::Encode $encoder .= new;
      $b = [~] Buf.new(BSON::C-DOCUMENT), encode-e-name($key),
            $encoder.encode($d);
    }

    when Array {
      # Array
      # "\x04" e_name document

      # The document for an array is a normal BSON document with integer
      # values for the keys counting from 0 and up sequentially.
      # For example, the array ['red', 'blue'] would be encoded as the
      # document ('0' => 'red', '1' => 'blue'). The keys must be in ascending
      # numerical order.
      my BSON::Encode $encoder .= new;
      my BSON::Document $d .= new: (
        (for $value.kv -> $ka, $va { "$ka" => $va });
      );
      $b = [~] Buf.new(BSON::C-ARRAY), encode-e-name($key),
            $encoder.encode($d);
    }

    when BSON::Binary {
      # Binary data
      # "\x05" e_name int32 subtype byte*
      # subtype is '\x00' for the moment (Generic binary subtype)
      #
      $b = [~] Buf.new(BSON::C-BINARY), encode-e-name($key),
               $value.encode;
    }

    when BSON::ObjectId {
      # ObjectId
      # "\x07" e_name (byte*12)
      #
      $b = [~] Buf.new(BSON::C-OBJECTID), encode-e-name($key),
               $value.encode;
    }

    when Bool {
      # Bool
      # \0x08 e_name (\0x00 or \0x01)
      #
      if $value.Bool {
        # Boolean "true"
        # "\x08" e_name "\x01
        #
        $b = [~] Buf.new(BSON::C-BOOLEAN),
                 encode-e-name($key),
                 Buf.new(0x01);
      }

      else {
        # Boolean "false"
        # "\x08" e_name "\x00
        #
        $b = [~] Buf.new(BSON::C-BOOLEAN),
                 encode-e-name($key),
                 Buf.new(0x00);
      }
    }

    when DateTime {
      # UTC dateime
      # "\x09" e_name int64
      #
      $b = [~] Buf.new(BSON::C-DATETIME),
               encode-e-name($key),
                Buf.new.write-int64(
                  0, ( ( $value.posix + $value.second - $value.whole-second
                       ) * 1000
                     ).Int,
                  LittleEndian
                );
#               encode-int64(((
#                 $value.posix + $value.second - $value.whole-second
#               ) * 1000).Int);
    }

    when BSON::Regex {
      # Regular expression
      # "\x0B" e_name cstring cstring
      #
      $b = [~] Buf.new(BSON::C-REGEX),
               encode-e-name($key),
               encode-cstring($value.regex),
               encode-cstring($value.options);
    }

    # This entry does 2 codes. 0x0D for javascript only and 0x0F when
    # there is a scope document defined in the object
    #
    when BSON::Javascript {
      # Javascript code
      # "\x0D" e_name string
      # "\x0F" e_name int32 string document
      #
      if $value.has-scope {
        $b = [~] Buf.new(BSON::C-JAVASCRIPT-SCOPE),
                 encode-e-name($key),
                 $value.encode;
      }

      else {
        $b = [~] Buf.new(BSON::C-JAVASCRIPT),
                 encode-e-name($key),
                 $value.encode;
      }
    }

    when Int {
      # Integer
      # "\x10" e_name int32
      # '\x12' e_name int64
      #
      if -0x7fffffff <= $value <= 0x7fffffff {
        $b = [~] Buf.new(BSON::C-INT32),
                 encode-e-name($key),
                 Buf.new.write-int32( 0, $value, LittleEndian);
#                 encode-int32($value);
      }

      elsif -0x7fffffff_ffffffff <= $value <= 0x7fffffff_ffffffff {
        $b = [~] Buf.new(BSON::C-INT64),
                 encode-e-name($key),
                 Buf.new.write-int64( 0, $value, LittleEndian);
#                 encode-int64($value);
      }

      else {
        my $reason = 'small' if $value < -0x7fffffff_ffffffff;
        $reason = 'large' if $value > 0x7fffffff_ffffffff;
        die X::BSON.new(
          :operation<encode>, :type<Int>,
          :error("Number too $reason")
        );
      }
    }

    when BSON::Timestamp {
      # timestamp as an unsigned 64 bit integer
      # '\x11' e_name int64
      $b = [~] Buf.new(BSON::C-TIMESTAMP),
               encode-e-name($key),
#               encode-uint64($value);
               Buf.new.write-uint64( 0, $value, LittleEndian);
    }

    when BSON::Decimal128 {
      #`{{
      $b = [~] Buf.new(BSON::C-DECIMAL128),
               encode-e-name($key),
               $value.encode;

      }}

      die X::BSON.new(
        :operation<encode>, :type('BSON::Decimal128'),
        :error('Not yet implemented')
      );
    }

    when !.defined {
      # Nil == Undefined value == typed object
      # "\x0A" e_name
      #
      $b = Buf.new(BSON::C-NULL) ~ encode-e-name($key);
    }

    default {
      die X::BSON.new( :operation<encode>, :type($_), :error('Not yet implemented'));
    }
  }

  $b
}

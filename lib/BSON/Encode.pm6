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
unit class BSON::Encode:auth<github:MARTIMM>:ver<0.1.0>;


has UInt $!index = 0;
#has %!promises is Hash::Ordered;
#has Buf $!encoded-document;
has Buf @!encoded-entries;

#----------------------------------------------------------------------------
# Called from user to get a complete encoded document or by a request
# from an encoding Document to encode a subdocument or array.
#  method encode ( $document: --> Buf ) {
method encode ( BSON::Document $document --> Buf ) {

  # encode all in parallel except for Arrays and Documents. This level must
  # be done first.

  my $idx = 0;
  for $document.keys -> $k {
#    my $v = $document{$k};
#note "E0: $k, $v";
#    if $v.^name ~~ any(<Array BSON::Document Hash::Ordered>) {
#note "skip $k, ", $v.^name, " for the moment";
#      next;
#    }

#    %!promises{$k} = Promise.start( {
#        @!encoded-entries[$idx] = self!encode-element: ($k => $v);
#      }
#    );
#`{{
    given $document{$k}.^name {
      when 'Array' {
        # The document for an array is a normal BSON document with integer
        # values for the keys counting from 0 and up sequentially.
        # For example, the array ['red', 'blue'] would be encoded as the
        # document ('0' => 'red', '1' => 'blue'). The keys must be in ascending
        # numerical order.
        my $pairs = (for $document{$k}.kv -> $ka, $va { "$ka" => $va });
        my BSON::Document $d .= new: ($pairs);
        @!encoded-entries[$idx] =
          [~] Buf.new(BSON::C-ARRAY), encode-e-name($k), self.encode($d);
      }

      when 'BSON::Document' {
        @!encoded-entries[$idx] =
          [~] Buf.new(BSON::C-DOCUMENT), encode-e-name($k),
              self.encode($document{$k});
      }

#`{{
      when 'Hash::Ordered' {
        require ::('BSON::Document');
        my $d = ::('BSON::Document').new($document{$k});
        @!encoded-entries[$idx] =
          [~] Buf.new(BSON::C-DOCUMENT), encode-e-name($k), $d.encode;
      }
}}
      default {
        @!encoded-entries[$idx] = self!encode-element: ($k => $v);
      }
    }
}}

#    @!encoded-entries[$idx] = self!encode-element: ($k => $document{$k});
    @!encoded-entries[$idx] = self!encode-element( $k, $document{$k});
    $idx++;
  }
#`{{
  for ^@!keys.elems -> $idx {
    my $v = @!values[$idx];
    next if $v ~~ any(Array|BSON::Document);

    my $k = @!keys[$idx];
    %!promises{$k} = Promise.start( {
        self!encode-element: ($k => $v);
      }
    );
  }
}}
#  await %!promises.values;
#`{{
  # Clear old entries
  @!encoded-entries = ();
  my $idx = 0;
  for $document.keys -> $k {
#note "E1: $k";
    @!encoded-entries[$idx] = %!promises{$k}.result
      if %!promises{$k}.defined;

    $idx++;
  }
}}

#`{{
  for ^@!keys.elems -> $idx {
    my $key = @!keys[$idx];
    next unless %!promises{$key}.defined;
    @!encoded-entries[$idx] = %!promises{$key}.result;
  }
}}
#  %!promises = ();
#`{{
  $idx = 0;
  for $document.keys -> $k {
note "Now fill in $k, ", $document{$k}.^name if $document{$k}.^name ~~ any(<Array BSON::Document Hash::Ordered>);
    given $document{$k}.^name {
      when 'Array' {
        # The document for an array is a normal BSON document with integer
        # values for the keys counting with 0 and continuing sequentially.
        # For example, the array ['red', 'blue'] would be encoded as the
        # document ('0': 'red', '1': 'blue'). The keys must be in ascending
        # numerical order.
        my $pairs = (for $document{$k}.kv -> $ka, $va { "$ka" => $va });
        my Hash::Ordered $d .= new($pairs);
        @!encoded-entries[$idx] =
          [~] Buf.new(BSON::C-ARRAY), encode-e-name($k), $d.encode;
      }

      when 'BSON::Document' {
        @!encoded-entries[$idx] =
          [~] Buf.new(BSON::C-DOCUMENT), encode-e-name($k),
              $document{$k}.encode;
      }

      when 'Hash::Ordered' {
        require ::('BSON::Document');
        my $d = ::('BSON::Document').new($document{$k});
        @!encoded-entries[$idx] =
          [~] Buf.new(BSON::C-DOCUMENT), encode-e-name($k), $d.encode;
      }
    }

    $idx++;
  }
}}
#`{{
  # filling the gaps of arays and nested documents
  for ^@!keys.elems -> $idx {
    my $key = @!keys[$idx];
    if @!values[$idx] ~~ Array {

      # The document for an array is a normal BSON document with integer values
      # for the keys counting with 0 and continuing sequentially.
      # For example, the array ['red', 'blue'] would be encoded as the document
      # ('0': 'red', '1': 'blue'). The keys must be in ascending numerical order.

      my $pairs = (for @!values[$idx].kv -> $k, $v { "$k" => $v });
      my BSON::Document $d .= new($pairs);
      @!encoded-entries[$idx] = [~] Buf.new(BSON::C-ARRAY),
                                    encode-e-name($key),
                                    $d.encode;
    }

    elsif @!values[$idx] ~~ BSON::Document {
      @!encoded-entries[$idx] = [~] Buf.new(BSON::C-DOCUMENT),
                                    encode-e-name($key),
                                    @!values[$idx].encode;
    }
  }
}}

  # if there are entries
  my Buf $encoded-document = Buf.new;
  for @!encoded-entries -> $e {
#    next unless $e.defined;
    $encoded-document ~= $e;
  }

  # encode size: number of elems + null byte at the end
  my Buf $b = [~] encode-int32($encoded-document.elems + 5),
      $encoded-document, Buf.new(0x00);

  $b
}

#----------------------------------------------------------------------------
# Encode a key value pair. Called from the insertion methods above when a
# key value pair is inserted.
#
# element ::= type-code e_name some-encoding
#
#method !encode-element ( Pair:D $p --> Buf ) {
method !encode-element ( Str $key, $value --> Buf ) {
#note "Encode element: :$key, ", $key.WHAT, ", $value, ", $value.WHAT;

  my Buf $b;

  given $value {

    # skip all temporay containers
#      when TemporaryContainer {
#note "Tempvalue: KV: $p.perl()";
#        $b = [~] Buf.new()
#      }

#`{{
	  when FatRat {
      # encode as binary FatRat
      # not yet implemented when proceding
      proceed;
    }

	  when Rat {
		  # Only handle Rat if it can be converted without precision loss
		  if $!convert-rat || $convert-rat {
        if $accept-loss || .Num.Rat(0) == $_ {
  			  $_ .= Num;

          # Now that Rat is converted to Num, proceed to encode the Num. But
          # when the Rat stays a Rat, it will end up in an exception.
          proceed;
        }

        else {
          die X::BSON.new(
            :operation<encode>,
            :type($_),
            :error('Rat can not be converted without losing pecision')
          );
        }
		  }

      else {
        # encode as binary Rat
        # not yet implemented when proceding
        proceed;
      }
	  }
}}

    when Num {
#note 'Num';
      # Double precision
      # "\x01" e_name Num
      #
      $b = [~] Buf.new(BSON::C-DOUBLE),
               encode-e-name($key),
               encode-double($value);
    }

    when Str {
#note 'Str';
      # UTF-8 string
      # "\x02" e_name string
      #
      $b = [~] Buf.new(BSON::C-STRING),
               encode-e-name($key),
               encode-string($value);
    }

    when BSON::Ordered {
#note 'BSON::Document';
      # Embedded document
      # "\x03" e_name document
# this handled separately after encoding is done for non-docs/arrays

        my BSON::Document $d .= new: (
          (for $value.kv -> $ka, $va { "$ka" => $va })
        );

        my BSON::Encode $encoder .= new;
        $b = [~] Buf.new(BSON::C-DOCUMENT), encode-e-name($key),
              $encoder.encode($d);
    }

    when Array {
#note 'Array';
      # Array
      # "\x04" e_name document

# this handled separately after encoding is done for non-docs/arrays

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
#note 'BSON::Binary';
      # Binary data
      # "\x05" e_name int32 subtype byte*
      # subtype is '\x00' for the moment (Generic binary subtype)
      #
      $b = [~] Buf.new(BSON::C-BINARY), encode-e-name($key),
               $value.encode;
    }

    when BSON::ObjectId {
#note 'BSON::ObjectId';
      # ObjectId
      # "\x07" e_name (byte*12)
      #
      $b = [~] Buf.new(BSON::C-OBJECTID), encode-e-name($key),
               $value.encode;
    }

    when Bool {
#note 'Bool';
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
#note 'DateTime';
      # UTC dateime
      # "\x09" e_name int64
      #
      $b = [~] Buf.new(BSON::C-DATETIME),
               encode-e-name($key),
               encode-int64(((
                 $value.posix + $value.second - $value.whole-second
               ) * 1000).Int);
    }

    when BSON::Regex {
#note 'BSON::Regex';
      # Regular expression
      # "\x0B" e_name cstring cstring
      #
      $b = [~] Buf.new(BSON::C-REGEX),
               encode-e-name($key),
               encode-cstring($value.regex),
               encode-cstring($value.options);
    }

#`{{
    when ... {
      # DBPointer - deprecated
      # "\x0C" e_name string (byte*12)
      #
      die X::BSON.new(
        :operation('encoding DBPointer'), :type('0x0C'),
        :error('DBPointer is deprecated')
      );
    }
}}

    # This entry does 2 codes. 0x0D for javascript only and 0x0F when
    # there is a scope document defined in the object
    #
    when BSON::Javascript {
#note 'BSON::Javascript';
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
#note 'Int';
      # Integer
      # "\x10" e_name int32
      # '\x12' e_name int64
      #
#note "$key, $value";
      if -0x7fffffff <= $value <= 0x7fffffff {
        $b = [~] Buf.new(BSON::C-INT32),
                 encode-e-name($key),
                 encode-int32($value);
      }

      elsif -0x7fffffff_ffffffff <= $value <= 0x7fffffff_ffffffff {
        $b = [~] Buf.new(BSON::C-INT64),
                 encode-e-name($key),
                 encode-int64($value);
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
#note 'BSON::Timestamp';
      # timestamp as an unsigned 64 bit integer
      # '\x11' e_name int64
      $b = [~] Buf.new(BSON::C-TIMESTAMP),
               encode-e-name($key),
               encode-uint64($value);
    }

    when BSON::Decimal128 {
#note 'BSON::Decimal128';
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
#note '!.defined';
      # Nil == Undefined value == typed object
      # "\x0A" e_name
      #
      $b = Buf.new(BSON::C-NULL) ~ encode-e-name($key);
    }

    default {
#note 'default';
      die X::BSON.new( :operation<encode>, :type($_), :error('Not yet implemented'));
    }
  }

#note "Encoded element: :$key, ", $key.WHAT, ", $value, ", $value.WHAT, ', ', $b;

  $b
}

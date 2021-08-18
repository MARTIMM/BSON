use v6.d;

use BSON;
use BSON::ObjectId;
use BSON::Binary;
use BSON::Decimal128;
use BSON::Javascript;
use BSON::Regex;

use Hash::Ordered;

#------------------------------------------------------------------------------
unit class BSON::Encode:auth<github:MARTIMM>:ver<0.1.0>;

subset Index of Int where $_ >= 0;

has %!document is Hash::Ordered;

has Index $!index = 0;
has %!promises is Hash::Ordered;
has Buf $!encoded-document;
has Buf @!encoded-entries;

#----------------------------------------------------------------------------
# Called from user to get a complete encoded document or by a request
# from an encoding Document to encode a subdocument or array.
#  method encode ( $document: --> Buf ) {
method encode ( %!document --> Buf ) {

  # encode all in parallel except for Arrays and Documents. This level must
  # be done first.

  for %!document.keys -> $k {
    my $v = %!document{$k};
#note "E0: $k, $v";
    if $v.^name ~~ any(<Array BSON::Document Hash::Ordered>) {
note "skip $k, ", $v.^name, " for the moment";
      next;
    }

    %!promises{$k} = Promise.start( {
        self!encode-element: ($k => $v);
      }
    );
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
  await %!promises.values;

  # Clear old entries
  @!encoded-entries = ();
  my $idx = 0;
  for %!document.keys -> $k {
#note "E1: $k";
    @!encoded-entries[$idx] = %!promises{$k}.result
      if %!promises{$k}.defined;

    $idx++;
  }


#`{{
  for ^@!keys.elems -> $idx {
    my $key = @!keys[$idx];
    next unless %!promises{$key}.defined;
    @!encoded-entries[$idx] = %!promises{$key}.result;
  }
}}
  %!promises = ();

  $idx = 0;
  for %!document.keys -> $k {
note "Now fill in $k, ", %!document{$k}.^name if %!document{$k}.^name ~~ any(<Array BSON::Document Hash::Ordered>);
    given %!document{$k}.^name {
      when 'Array' {
        # The document for an array is a normal BSON document with integer
        # values for the keys counting with 0 and continuing sequentially.
        # For example, the array ['red', 'blue'] would be encoded as the
        # document ('0': 'red', '1': 'blue'). The keys must be in ascending
        # numerical order.
        my $pairs = (for %!document{$k}.kv -> $ka, $va { "$ka" => $va });
        my Hash::Ordered $d .= new($pairs);
        @!encoded-entries[$idx] =
          [~] Buf.new(BSON::C-ARRAY), encode-e-name($k), $d.encode;
      }

      when 'BSON::Document' {
        @!encoded-entries[$idx] =
          [~] Buf.new(BSON::C-DOCUMENT), encode-e-name($k),
              %!document{$k}.encode;
      }

      when 'Hash::Ordered' {
        require ::('BSON::Document');
        my $d = ::('BSON::Document').new(%!document{$k});
        @!encoded-entries[$idx] =
          [~] Buf.new(BSON::C-DOCUMENT), encode-e-name($k), $d.encode;
      }
    }

    $idx++;
  }

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
  $!encoded-document = Buf.new;
  for @!encoded-entries -> $e {
    next unless $e.defined;
    $!encoded-document ~= $e;
  }

  # encode size: number of elems + null byte at the end
  my Buf $b = [~] encode-int32($!encoded-document.elems + 5),
      $!encoded-document,
      Buf.new(0x00);
  $b
}

#----------------------------------------------------------------------------
# Encode a key value pair. Called from the insertion methods above when a
# key value pair is inserted.
#
# element ::= type-code e_name some-encoding
#
method !encode-element ( Pair:D $p --> Buf ) {
note "Encode element: :$p.key()\($p.value()\), ", $p.key.WHAT, ', ', $p.value.WHAT;

  my Buf $b;

  given $p.value.^name {

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

    when 'Num' {
      # Double precision
      # "\x01" e_name Num
      #
      $b = [~] Buf.new(BSON::C-DOUBLE),
               encode-e-name($p.key),
               encode-double($p.value);
    }

    when 'Str' {
      # UTF-8 string
      # "\x02" e_name string
      #
      $b = [~] Buf.new(BSON::C-STRING),
               encode-e-name($p.key),
               encode-string($p.value);
    }

    when 'BSON::Document' {
      # Embedded document
      # "\x03" e_name document
      # this handled separately after encoding is done for non-docs/arrays
    }

    when 'Array' {
      # Array
      # "\x04" e_name document
      # this handled separately after encoding is done for non-docs/arrays
    }

    when 'BSON::Binary' {
      # Binary data
      # "\x05" e_name int32 subtype byte*
      # subtype is '\x00' for the moment (Generic binary subtype)
      #
      $b = [~] Buf.new(BSON::C-BINARY), encode-e-name($p.key),
               $p.value.encode;
    }

    when 'BSON::ObjectId' {
      # ObjectId
      # "\x07" e_name (byte*12)
      #
      $b = [~] Buf.new(BSON::C-OBJECTID), encode-e-name($p.key),
               $p.value.encode;
    }

    when 'Bool' {
      # Bool
      # \0x08 e_name (\0x00 or \0x01)
      #
      if $p.value.Bool {
        # Boolean "true"
        # "\x08" e_name "\x01
        #
        $b = [~] Buf.new(BSON::C-BOOLEAN),
                 encode-e-name($p.key),
                 Buf.new(0x01);
      }
      else {
        # Boolean "false"
        # "\x08" e_name "\x00
        #
        $b = [~] Buf.new(BSON::C-BOOLEAN),
                 encode-e-name($p.key),
                 Buf.new(0x00);
      }
    }

    when 'DateTime' {
      # UTC dateime
      # "\x09" e_name int64
      #
      $b = [~] Buf.new(BSON::C-DATETIME),
               encode-e-name($p.key),
               encode-int64(((
                 $p.value.posix + $p.value.second - $p.value.whole-second
               ) * 1000).Int);
    }

    when 'Any' {
      # Nil == Undefined value == typed object
      # "\x0A" e_name
      #
      $b = Buf.new(BSON::C-NULL) ~ encode-e-name($p.key);
    }

    when 'BSON::Regex' {
      # Regular expression
      # "\x0B" e_name cstring cstring
      #
      $b = [~] Buf.new(BSON::C-REGEX),
               encode-e-name($p.key),
               encode-cstring($p.value.regex),
               encode-cstring($p.value.options);
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
    when 'BSON::Javascript' {

      # Javascript code
      # "\x0D" e_name string
      # "\x0F" e_name int32 string document
      #
      if $p.value.has-scope {
        $b = [~] Buf.new(BSON::C-JAVASCRIPT-SCOPE),
                 encode-e-name($p.key),
                 $p.value.encode;
      }

      else {
        $b = [~] Buf.new(BSON::C-JAVASCRIPT),
                 encode-e-name($p.key),
                 $p.value.encode;
      }
    }

    when 'Int' {
      # Integer
      # "\x10" e_name int32
      # '\x12' e_name int64
      #
      if -0x7fffffff <= $p.value <= 0x7fffffff {
        $b = [~] Buf.new(BSON::C-INT32),
                 encode-e-name($p.key),
                 encode-int32($p.value);
      }

      elsif -0x7fffffff_ffffffff <= $p.value <= 0x7fffffff_ffffffff {
        $b = [~] Buf.new(BSON::C-INT64),
                 encode-e-name($p.key),
                 encode-int64($p.value);
      }

      else {
        my $reason = 'small' if $p.value < -0x7fffffff_ffffffff;
        $reason = 'large' if $p.value > 0x7fffffff_ffffffff;
        die X::BSON.new(
          :operation<encode>, :type<Int>,
          :error("Number too $reason")
        );
      }
    }

    when 'BSON::Timestamp' {
      # timestamp as an unsigned 64 bit integer
      # '\x11' e_name int64
      $b = [~] Buf.new(BSON::C-TIMESTAMP),
               encode-e-name($p.key),
               encode-uint64($p.value);
    }

    when 'BSON::Decimal128' {
      #`{{
      $b = [~] Buf.new(BSON::C-DECIMAL128),
               encode-e-name($p.key),
               $p.value.encode;

      }}

      die X::BSON.new(
        :operation<encode>, :type('BSON::Decimal128'),
        :error('Not yet implemented')
      );
    }

    default {
      die X::BSON.new( :operation<encode>, :type($_), :error('Not yet implemented'));
    }
  }

#note "\nEE: ", ", {$p.key} => {$p.value//'(Any)'}: ", $p.value.WHAT, ', ', $b;

  $b
}

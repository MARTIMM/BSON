use v6;
#use BSON;
#use BSON::EDCTools;
use BSON::Double;
use BSON::ObjectId;
use BSON::Regex;
use BSON::Javascript;
use BSON::Binary;
use BSON::Exception;

package BSON {

  constant C-DOUBLE             = 0x01;
  constant C-STRING             = 0x02;
  constant C-DOCUMENT           = 0x03;
  constant C-ARRAY              = 0x04;
  constant C-BINARY             = 0x05;
  constant C-UNDEFINED          = 0x06;         # Deprecated
  constant C-OBJECTID           = 0x07;
  constant C-BOOLEAN            = 0x08;
  constant C-DATETIME           = 0x09;
  constant C-NULL               = 0x0A;
  constant C-REGEX              = 0x0B;
  constant C-DBPOINTER          = 0x0C;         # Deprecated
  constant C-JAVASCRIPT         = 0x0D;
  constant C-DEPRECATED         = 0x0E;         # Deprecated
  constant C-JAVASCRIPT-SCOPE   = 0x0F;
  constant C-INT32              = 0x10;
  constant C-TIMESTAMP          = 0x11;
  constant C-INT64              = 0x12;
  constant C-MIN-KEY            = 0xFF;
  constant C-MAX-KEY            = 0x7F;

  #-----------------------------------------------------------------------------
  constant C-INT32-SIZE         = 4;
  constant C-INT64-SIZE         = 8;
  constant C-DOUBLE-SIZE        = 8;

  sub int32-size ( --> Int ) { C-INT32-SIZE }
  sub int64-size ( --> Int ) { C-INT64-SIZE }
  sub double-size ( --> Int ) { C-DOUBLE-SIZE }

  class Document does Associative does Positional {

    subset Index of Int where $_ >= 0;

    has Str @!keys;
    has Hash $!data .= new;

#    has BSON::Bson $bson;
    has Buf $!encoded-document;
    has Buf @!encoded-entries;
    has Index $!index = 0;


    # Encoded turns
    # 1) True on init, no need to 'await' promises.
    # 2) False on insert, delete or modify an entry
    # 3) True on encode() and decode()
    #
    has Bool $!encoded;
#    has Bool $!promises-wait;

    # Decoded turns
    # 1) False on init
    # 2) False on loading into $!encoded-document
    # 3) True on encode() and decode()
    #
    has Bool $!decoded;

    has Promise %!promises;
    has $!start-time;

    #---------------------------------------------------------------------------
    #
    method new ( *@ps ) {
      self.bless(:pairs(@ps));
    }

    submethod BUILD (:@pairs) {

      $!encoded = True;
      $!decoded = False;
#      $!bson .= new;

      # self{x} = y will end up at ASSIGN-KEY
      #
      for @pairs -> $pair {
        self{$pair.key} = $pair.value;
      }
    }

    #---------------------------------------------------------------------------
    # Associative role methods
    #---------------------------------------------------------------------------
    multi method AT-KEY ( Str $key --> Any ) {

      $!data{$key}:exists ?? $!data{$key} !! Any;
    }

    #---------------------------------------------------------------------------
    multi method EXISTS-KEY ( Str $key --> Bool ) {

      return $!data{$key}:exists;
    }

    #---------------------------------------------------------------------------
    multi method DELETE-KEY ( Str $key --> Any ) {

      my $value;
      if $!data{$key}:exists {
        loop ( my $i = 0; $i < @!keys.elems; $i++ ) {
          if @!keys[$i] ~~ $key {
            @!keys.splice( $i, 1);
#say "Key = $key, i = $i, #ee: {@!encoded-entries.elems}";
            @!encoded-entries.splice( $i, 1) if @!encoded-entries.elems;   # $!encoded kept to True!
            $value = $!data{$key}:delete;
            last;
          }
        }
      }

      $value;
    }

    #---------------------------------------------------------------------------
    multi method ASSIGN-KEY ( $key, $new) {

      @!keys.push($key) unless $!data{$key}:exists;
      $!data{$key} = $new;

      %!promises{$key}:delete if %!promises{$key}:exists;
      %!promises{$key} = Promise.start( {

          self!encode-element: ($key => $!data{$key});
        }
      );

      $!encoded = False;
    }

    #---------------------------------------------------------------------------
#`{{
Cannot use binding because when value changes the object cannot know that the
location is changed. This is nessesary to encode the key, value pair.
}}
    multi method BIND-KEY ( Str $key, \new ) {

      die "Can not use binding";
#      $!data{$key} := new;
    }


    #---------------------------------------------------------------------------
    # Positional role methods
    #---------------------------------------------------------------------------
    multi method elems ( --> Int ) {

      @!keys.elems;
    }

    #---------------------------------------------------------------------------
    multi method AT-POS ( Index $idx --> Any ) {

      $idx < @!keys.elems ?? $!data{@!keys[$idx]} !! Any;
    }

    #---------------------------------------------------------------------------
    multi method EXISTS-POS ( Index $idx --> Bool ) {

      $idx < @!keys.elems;
    }

    #---------------------------------------------------------------------------
    multi method DELETE-POS ( Index $idx --> Any ) {

      $idx < @!keys.elems ?? (self{@!keys[$idx]}:delete) !! Nil;
    }

    #---------------------------------------------------------------------------
    multi method ASSIGN-POS ( Index $idx, $new! ) {

      # If index is at a higher position then the last one then only
      # one place extended with a generated key na,e such as key21 on the
      # 21st location. Furthermore when a key like key21 has been used before
      # the array is not extended but the key location is used instead.
      #
      my $key = $idx >= @!keys.elems ?? 'key' ~ $idx !! @!keys[$idx];

      @!keys.push($key) unless $!data{$key}:exists;
      $!data{$key} = $new;

      %!promises{$key}:delete if %!promises{$key}:exists;
      %!promises{$key} = Promise.start( {
          self!encode-element: ($key => $!data{$key});
        }
      );

      $!encoded = False;
    }

    #---------------------------------------------------------------------------
#`{{
Cannot use binding because when value changes the object cannot know that the
location is changed. This is nessesary to encode the key, value pair.
}}
    multi method BIND-POS ( Index $idx, \new ) {

      die "Can not use binding";
#      my $key = $idx >= @!keys.elems ?? 'key' ~ $idx !! @!keys[$idx];
#      $!data{$key} := new;
    }

    #---------------------------------------------------------------------------
    # Must be defined because of Positional and Associative sources of of()
    #---------------------------------------------------------------------------
    method of ( ) {
      Mu;
    }

    #---------------------------------------------------------------------------
    # And some extra methods
    #---------------------------------------------------------------------------
    multi method kv ( --> List ) {

      my @l;
      for @!keys -> $k {
        @l.push( $k, $!data{$k});
      }

      @l;
    }

    #---------------------------------------------------------------------------
    multi method keys ( --> List ) {

      @!keys.list;
    }

    #---------------------------------------------------------------------------
    multi method values ( --> List ) {

      $!data{@!keys[*]}.list;
    }

    #---------------------------------------------------------------------------
    # Encoding document
    #---------------------------------------------------------------------------
    # Called from user to get encoded document
    #
    method encode ( --> Buf ) {

      if !$!encoded {
        loop ( my $idx = 0; $idx < @!keys.elems; $idx++) {
          my $key = @!keys[$idx];
          @!encoded-entries[$idx] = await %!promises{$key}
            if %!promises{$key}:exists;
        }

        $!encoded = True;
        %!promises = ();
      }

      $!encoded-document = [~] @!encoded-entries;

      [~] encode-int32($!encoded-document.elems + 5),
          $!encoded-document,
          Buf.new(0x00);
    }

    #---------------------------------------------------------------------------
    # Encode a key value pair
    # element ::= type-code e_name some-encoding
    #
    method !encode-element ( Pair:D $p --> Buf ) {

      given $p.value {

        when Num {
          # Double precision
          # "\x01" e_name Num
          #
#          return BSON::Double.encode-double($p);

          return [~] Buf.new(0x01),
                     encode-e-name($p.key),
                     BSON::Double.encode-double($p.value);
        }

        when Str {
          # UTF-8 string
          # "\x02" e_name string
          #
          return [~] Buf.new(0x02),
                     encode-e-name($p.key),
                     encode-string($p.value)
                     ;
        }

        # Converting a pair same way as a hash:
        #
        when Pair {
          # Embedded document
          # "\x03" e_name document
          #
          my Pair @pairs = $p.value;
          return [~] Buf.new(0x03),
                     encode-e-name($p.key),
                     self.encode-document(@pairs)
                     ;
        }

        when Hash {
          # Embedded document
          # "\x03" e_name document
          #
          return [~] Buf.new(0x03),
                     encode-e-name($p.key),
                     self.encode-document($p.value)
                     ;
        }

        when Array {
          # Array
          # "\x04" e_name document

          # The document for an array is a normal BSON document
          # with integer values for the keys,
          # starting with 0 and continuing sequentially.
          # For example, the array ['red', 'blue']
          # would be encoded as the document {'0': 'red', '1': 'blue'}.
          # The keys must be in ascending numerical order.
          #
          # Simple assigning .kv to %hash wouldn't work because the order
          # of items can go wrong. Mongo doesn't process it very well if e.g.
          # { 1 => 'abc', 0 => 'def' } was encoded instead of
          # { 0 => 'def', 1 => 'abc' }.
          #
           my Pair @pairs;
          for .kv -> $k, $v {
            @pairs.push: ("$k" => $v);
          }

          return [~] Buf.new(0x04),
                     encode-e-name($p.key),
                     self.encode-document(@pairs)
                     ;
        }

        when BSON::Binary {
          # Binary data
          # "\x05" e_name int32 subtype byte*
          # subtype is '\x00' for the moment (Generic binary subtype)
          #
          return [~] Buf.new(0x05), encode-e-name($p.key), .encode-binary();
        }

  #`{{
        # Do not know what type to test. Any, Nil?
        when Any {
          # Undefined deprecated 
          # "\x06" e_name
          #
          die X::BSON::Deprecated.new(
            operation => 'encode',
            type => 'Undefined(0x06)'
          );
        }
  }}
        when BSON::ObjectId {
          # ObjectId
          # "\x07" e_name (byte*12)
          #
          return Buf.new(0x07) ~ encode-e-name($p.key) ~ .Buf;
        }

        when Bool {
          # Bool
          # \0x08 e_name (\0x00 or \0x01)
          #
          if .Bool {
            # Boolean "true"
            # "\x08" e_name "\x01
            #
            return Buf.new(0x08) ~ encode-e-name($p.key) ~ Buf.new(0x01);
          }
          else {
            # Boolean "false"
            # "\x08" e_name "\x00
            #
            return Buf.new(0x08) ~ encode-e-name($p.key) ~ Buf.new(0x00);
          }
        }

        when DateTime {
          # UTC dateime
          # "\x09" e_name int64
          #
          return [~] Buf.new(0x09),
                     encode-e-name($p.key),
                     encode-int64($p.value().posix())
                     ;
        }

        when not .defined {
          # Null value
          # "\x0A" e_name
          #
          return Buf.new(0x0A) ~ encode-e-name($p.key);
        }

        when BSON::Regex {
          # Regular expression
          # "\x0B" e_name cstring cstring
          #
          return [~] Buf.new(0x0B),
                     encode-e-name($p.key),
                     encode-cstring($p.value.regex),
                     encode-cstring($p.value.options)
                     ;
        }

  #`{{
        when ... {
          # DBPointer - deprecated
          # "\x0C" e_name string (byte*12)
          #
          die X::BSON::Deprecated(
            operation => 'encoding DBPointer',
            type => '0x0C'
          );
        }
  }}

        # This entry does 2 codes. 0x0D for javascript only and 0x0F when
        # there is a scope document defined in the object
        #
        when BSON::Javascript {

          return .encode-javascript( $p.key, self);
#`{{
          # Javascript code
          # "\x0D" e_name string
          # "\x0F" e_name int32 string document
          #
          if $p.value.has_javascript {
            my Buf $js = encode-string($p.value.javascript);

            if $p.value.has_scope {
              my Buf $doc = self.encode-document($p.value.scope);
              return [~] Buf.new(0x0F),
                         encode-e-name($p.key),
                         encode-int32([+] $js.elems, $doc.elems, 4),
                         $js, $doc
                         ;
            }

            else {
              return [~] Buf.new(0x0D), encode-e-name($p.key), $js;
            }
          }

          else {
            die X::BSON::ImProperUse.new( :operation('encode'),
                                          :type('javascript 0x0D/0x0F'),
                                          :emsg('cannot send empty code')
                                        );
          }
}}
        }

  #`{{
        when ... {
          # ? - deprecated
          # "\x0E" e_name string (byte*12)
          #
          die X::BSON::Deprecated(
            operation => 'encoding ?',
            type => '0x0E'
          );
        }

        when ... {
          # Javascript code with scope. Handled above.
          # "\x0F" e_name string document
        }
  }}

        when Int {
          # Integer
          # "\x10" e_name int32
          # '\x12' e_name int64
          #
          if -0xffffffff < $p.value < 0xffffffff {
            return [~] Buf.new(0x10),
                       encode-e-name($p.key),
                       encode-int32($p.value)
                       ;
          }

          elsif -0x7fffffff_ffffffff < $p.value < 0x7fffffff_ffffffff {
            return [~] Buf.new(0x12),
                       encode-e-name($p.key),
                       encode-int64($p.value)
                       ;
          }

          else {
            my $reason = 'small' if $p.value < -0x7fffffff_ffffffff;
            $reason = 'large' if $p.value > 0x7fffffff_ffffffff;
            die X::BSON::ImProperUse.new( :operation('encode'),
                                          :type('integer 0x10/0x12'),
                                          :emsg("cannot encode too $reason number")
                                        );
          }
        }

  #`{{
        when ... {
            # Timestamp. 
            # "\x11" e_name int64
            #
            # Special internal type used by MongoDB replication and
            # sharding. First 4 bytes are an increment, second 4 are a
            # timestamp.
        }
  }}

        when Buf {
          die X::BSON::ImProperUse.new(
              :operation('encode'),
              :type('Binary Buf'),
              :emsg('Buf not supported, please use BSON::Binary')
          );
        }

        default {
          if .can('encode') {
            my $code = 0x1F; # which bson code??

            return [~] Buf.new($code),
                       encode-e-name($p.key),
                       .encode;
                       ;
          }

          else {
            die X::BSON::NYS.new(
              :operation('encode'),
              :type($_ ~ '(' ~ $_.WHAT ~ ')')
            );
          }
        }
      }
    }

    #---------------------------------------------------------------------------
    sub encode-e-name ( Str:D $s --> Buf ) {
      return encode-cstring($s);
    }

    #---------------------------------------------------------------------------
    sub encode-cstring ( Str:D $s --> Buf ) {
      die X::BSON::Parse.new(
        :operation('encode_cstring'),
        :error('Forbidden 0x00 sequence in $s')
      ) if $s ~~ /\x00/;

      return $s.encode() ~ Buf.new(0x00);
    }

    #---------------------------------------------------------------------------
    sub encode-string ( Str:D $s --> Buf ) {
      my Buf $b .= new($s.encode('UTF-8'));
      return [~] encode-int32($b.bytes + 1), $b, Buf.new(0x00);
    }

    #---------------------------------------------------------------------------
    sub encode-int32 ( Int:D $i ) {
      my int $ni = $i;      
      return Buf.new( $ni +& 0xFF, ($ni +> 0x08) +& 0xFF,
                      ($ni +> 0x10) +& 0xFF, ($ni +> 0x18) +& 0xFF
                    );
    }

    #---------------------------------------------------------------------------
    sub encode-int64 ( Int:D $i ) {
      # No tests for too large/small numbers because it is called from
      # _enc_element normally where it is checked
      #
      my int $ni = $i;
      return Buf.new( $ni +& 0xFF, ($ni +> 0x08) +& 0xFF,
                      ($ni +> 0x10) +& 0xFF, ($ni +> 0x18) +& 0xFF,
                      ($ni +> 0x20) +& 0xFF, ($ni +> 0x28) +& 0xFF,
                      ($ni +> 0x30) +& 0xFF, ($ni +> 0x38) +& 0xFF
                    );

      # Original method goes wrong on negative numbers. Also modulo operations
      # are slower than the bit operations.
      #
      #return Buf.new( $i % 0x100, $i +> 0x08 % 0x100, $i +> 0x10 % 0x100,
      #                $i +> 0x18 % 0x100, $i +> 0x20 % 0x100,
      #                $i +> 0x28 % 0x100, $i +> 0x30 % 0x100,
      #                $i +> 0x38 % 0x100
      #              );
    }

    #---------------------------------------------------------------------------
    # Decoding document
    #---------------------------------------------------------------------------
    method decode ( Buf $data --> Nil ) {

      $!encoded-document = $data;
      $!encoded = True;
      $!decoded = False;

      @!keys = ();
      $!data .= new;

      # Document decoding start: init index
      #
      $!index = 0;
      $!start-time = time;

      # Decode the document, then wait for any started parallel tracks
      #
      self!decode-document;
      await %!promises.values if %!promises.elems;
    }

    #---------------------------------------------------------------------------
    method !decode-document ( --> Nil ) {

      # Get the size of the (nested-)document
      #
      my Int $doc-size = decode-int32( $!encoded-document, $!index);
      $!index += int32-size;

      while $!encoded-document[$!index] !~~ 0x00 {
        self!decode-element;
      }
      
      # Check size of document with final byte location
      #
      die "Size of document $doc-size does not match with index at $!index(+1)"
        if $doc-size != $!index + 1;
    }

    #---------------------------------------------------------------------------
    method !decode-element ( --> Nil ) {

      # Get the value type of next pair
      #
      my $bson-code = $!encoded-document[$!index++];

      # Get the key value
      #
      my Str $key = decode-e-name( $!encoded-document, $!index);

      @!keys.push($key);
      my Int $size;

      given $bson-code {

        # 64-bit floating point
        #
        when BSON::C-DOUBLE {

          my $i = $!index;
          $!index += double-size;
          %!promises{$key} = Promise.start( {
              $!data{$key} = BSON::Double.decode-double( $!encoded-document, $i);
              say "{time - $!start-time} Done $key => $!data{$key}";
            }
          );
        }

        # 32-bit Integer
        #
        when BSON::C-INT32 {

          my $i = $!index;
          $!index += int32-size;
          %!promises{$key} = Promise.start( {
              $!data{$key} = decode-int32( $!encoded-document, $i);
              say "{time - $!start-time} Done $key => $!data{$key}";
            }
          );
        }

        # 64-bit Integer
        #
        when BSON::C-INT64 {

          my $i = $!index;
          $!index += int64-size;
          %!promises{$key} = Promise.start( {
              $!data{$key} = decode-int64( $!encoded-document, $i);
              say "{time - $!start-time} Done $key => $!data{$key}";
            }
          );
        }

        default {
          # We must stop because we do not know what the length should be of
          # this particular structure.
          #
          die "BSON code '{.fmt('0x%02x')}' not supported";
        }
      }
    }

    #-----------------------------------------------------------------------------
    multi sub decode-e-name ( Buf:D $b, Int:D $index is rw --> Str ) {
      return decode-cstring( $b, $index);
    }

    #-----------------------------------------------------------------------------
    multi sub decode-cstring ( Buf:D $a, Int:D $index is rw --> Str ) {
      my @a;
      my $l = $a.elems;
      while $index < $l and $a[$index] !~~ 0x00 {
        @a.push($a[$index++]);
      }

      die X::BSON::Parse.new(
        :operation('decode-cstring'),
        :error('Missing trailing 0x00')
      ) unless $index < $l and $a[$index++] ~~ 0x00;

      return Buf.new(@a).decode();
    }

    #-----------------------------------------------------------------------------
    multi sub decode-int32 ( Buf:D $a, Int:D $index --> Int ) {

      # Check if there are enaugh letters left
      #
      die X::BSON::Parse.new(
        :operation('decode_int32'),
        :error('Not enaugh characters left')
      ) if $a.elems - $index < 4;

      my int $ni = $a[$index]             +| $a[$index + 1] +< 0x08 +|
                   $a[$index + 2] +< 0x10 +| $a[$index + 3] +< 0x18
                   ;
  #    $index += 4;

      # Test if most significant bit is set. If so, calculate two's complement
      # negative number.
      # Prefix +^: Coerces the argument to Int and does a bitwise negation on
      # the result, assuming two's complement. (See
      # http://doc.perl6.org/language/operators^)
      # Infix +^ :Coerces both arguments to Int and does a bitwise XOR
      # (exclusive OR) operation.
      #
      $ni = (0xffffffff +& (0xffffffff+^$ni) +1) * -1  if $ni +& 0x80000000;
      return $ni;
    }

    #-----------------------------------------------------------------------------
    multi sub decode-int64 ( Buf:D $a, Int:D $index is rw --> Int ) {
      # Check if there are enaugh letters left
      #
      die X::BSON::Parse.new(
        :operation('decode_int64'),
        :error('Not enaugh characters left')
      ) if $a.elems - $index < 8;

      my int $ni = $a[$index]             +| $a[$index + 1] +< 0x08 +|
                   $a[$index + 2] +< 0x10 +| $a[$index + 3] +< 0x18 +|
                   $a[$index + 4] +< 0x20 +| $a[$index + 5] +< 0x28 +|
                   $a[$index + 6] +< 0x30 +| $a[$index + 7] +< 0x38
                   ;
      $index += 8;
      return $ni;

      # Original method goes wrong on negative numbers. Also adding might be
      # slower than the bit operations.
      #
      #return [+] $a.shift, $a.shift +< 0x08, $a.shift +< 0x10, $a.shift +< 0x18
      #         , $a.shift +< 0x20, $a.shift +< 0x28, $a.shift +< 0x30
      #         , $a.shift +< 0x38
      #         ;
    }
  }
}


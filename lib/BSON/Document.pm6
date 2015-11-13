use v6;
use BSON;
use BSON::EDCTools;
use BSON::Double;

package BSON {

  class Document does Associative does Positional {

    has Str @!keys;
    has Hash $!data .= new;

#    has BSON::Bson $bson;
    has Buf $!encoded-document;
    has Buf @!encoded-entries;

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

    subset Index of Int where $_ >= 0;

    has Index $!index = 0;

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
          my BSON::Bson $bson .= new;
          $bson.encode-element: ($key => $!data{$key});
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
          my BSON::Bson $bson .= new;
          $bson.encode-element: ($key => $!data{$key});
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
    # Encoding and decoding
    #---------------------------------------------------------------------------
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
  }
}


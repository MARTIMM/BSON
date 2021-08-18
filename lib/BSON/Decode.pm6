use v6.d;

use BSON;
use BSON::ObjectId;
use BSON::Binary;
use BSON::Decimal128;
use BSON::Javascript;
use BSON::Regex;

use Hash::Ordered;

#------------------------------------------------------------------------------
unit class BSON::Decode:auth<github:MARTIMM>:ver<0.1.0>;

subset Index of Int where $_ >= 0;

has %!document is Hash::Ordered;

has Index $!index = 0;
has %!promises is Hash::Ordered;
has Buf $!encoded-document;
has Buf @!encoded-entries;

#------------------------------------------------------------------------------
method decode ( Buf:D $data --> Hash::Ordered ) {

  $!encoded-document = $data;

#    @!keys = ();
#    @!values = ();
  @!encoded-entries = ();

  # document decoding start: init index
  $!index = 0;

  # decode the document, then wait for any started parallel tracks
  # first get the size of the (nested-)document
  my Int $doc-size = decode-int32( $!encoded-document, $!index);
#note 'doc size: ', $doc-size;

  # step to the document content
  $!index += BSON::C-INT32-SIZE;

  # decode elements until end of doc (byte 0x00)
  while $!encoded-document[$!index] !~~ 0x00 {
#note "index: $!index, $!encoded-document[$!index]";
    self!decode-element;
  }

  # step over the last byte: index should now be the doc size
  $!index++;
#note "index: $!index == $doc-size";

  # check size of document with final byte location
  die X::BSON.new(
    :operation<decode>, :type<Document>,
    :error(
      [~] 'Size of document(', $doc-size,
          ') does not match with index(', $!index, ')'
    )
  ) if $doc-size != $!index;

  # wait for promises to end for this document
  self!process-decode-promises;

  %!document;
}

#----------------------------------------------------------------------------
method !decode-element ( --> Nil ) {

  # Decode start point
  my $decode-start = $!index;

  # Get the value type of next pair
  my $bson-code = $!encoded-document[$!index++];

  # Get the key value, Index is adjusted to just after the 0x00
  # of the string.
  my Str $key = decode-e-name( $!encoded-document, $!index);
#note "$*THREAD.id() $key found, type 0x$bson-code.fmt('%02x'), idx now $!index";

  # Keys are pushed in the proper order as they are seen in the
  # byte buffer.
#    my Int $idx = @!keys.elems;
#    @!keys[$idx] = $key;              # index on new location == push()
  my Int $idx = @!encoded-entries.elems;
  my Int $size;

  given $bson-code {

    # 64-bit floating point
    when BSON::C-DOUBLE {

#`{{
      my $c = -> $i is copy {
        my $v = decode-double( $!encoded-document, $i);
#note "DBL: $key, $idx = @!values[$idx]";

        # Return total section of binary data
        ( $v, $!encoded-document.subbuf(
                $decode-start ..^            # At bson code
                ($i + BSON::C-DOUBLE-SIZE)   # $i is at code + key further
              )
        )
      }
}}

      my Int $i = $!index;
      $!index += BSON::C-DOUBLE-SIZE;
#note "DBL Subbuf: ", $!encoded-document.subbuf( $i, BSON::C-DOUBLE-SIZE);
      %!promises{$key} = Promise.start( {
          my $v = decode-double( $!encoded-document, $i);
#note "DBL: $key, $idx = @!values[$idx]";

          # Return total section of binary data
          ( $v, $!encoded-document.subbuf(
                  $decode-start ..^            # At bson code
                  ($i + BSON::C-DOUBLE-SIZE)   # $i is at code + key further
                )
          )
        }
      );
    }

    # String type
    when BSON::C-STRING {

      my Int $i = $!index;
      my Int $nbr-bytes = decode-int32( $!encoded-document, $!index);

      # Step over the size field and the null terminated string
      $!index += BSON::C-INT32-SIZE + $nbr-bytes;

      %!promises{$key} = Promise.start( {
          my $v = decode-string( $!encoded-document, $i);

          ( $v, $!encoded-document.subbuf(
                  $decode-start ..^
                  ($i + BSON::C-INT32-SIZE + $nbr-bytes)
                )
          )
        }
      );
    }

    # Nested document
    when BSON::C-DOCUMENT {
      my Int $i = $!index;
      my Int $doc-size = decode-int32( $!encoded-document, $i);
      $!index += $doc-size;

      # Wait for any threads to complete before decoding the subdocument
      # If not, the threads are eaten up and we end up waiting for
      # non-started threads.
      self!process-decode-promises;

      require ::('BSON::Document');
      my $d = ::('BSON::Document').new;
      $d.decode($!encoded-document.subbuf($i ..^ ($i + $doc-size)));

      %!promises{$key} = Promise.start( {
          ( $d, $!encoded-document.subbuf( $decode-start ..^ ($i + $doc-size)))
        }
      );
    }

    # Array code
    when BSON::C-ARRAY {

      my Int $i = $!index;
      my Int $doc-size = decode-int32( $!encoded-document, $!index);
      $!index += $doc-size;

      self!process-decode-promises;
      %!promises{$key} = Promise.start( {
          require ::('BSON::Document');
          my $d = ::('BSON::Document').new;

          $d.decode($!encoded-document.subbuf($i ..^ ($i + $doc-size)));
          my $v = [$d.values];

          ( $v, $!encoded-document.subbuf( $decode-start ..^ ($i + $doc-size)))
        }
      );
    }

    # Binary code
    # "\x05 e_name int32 subtype byte*
    # subtype = byte \x00 .. \x05, .. \xFF
    # subtypes \x80 to \xFF are user defined
    when BSON::C-BINARY {

      my Int $buf-size = decode-int32( $!encoded-document, $!index);
      my Int $i = $!index + BSON::C-INT32-SIZE;

      # Step over size field, subtype and binary data
      $!index += BSON::C-INT32-SIZE + 1 + $buf-size;

      %!promises{$key} = Promise.start( {
          my $v = BSON::Binary.decode(
            $!encoded-document, $i, :$buf-size
          );

          ( $v, $!encoded-document.subbuf(
                  $decode-start ..^ ($i + 1 + $buf-size)
                )
          )
        }
      );
    }

    # Object id
    when BSON::C-OBJECTID {

      my Int $i = $!index;
      $!index += 12;

      %!promises{$key} = Promise.start( {
          my $v = BSON::ObjectId.decode( $!encoded-document, $i);
          ( $v, $!encoded-document.subbuf($decode-start ..^ ($i + 12)))
        }
      );
    }

    # Boolean code
    when BSON::C-BOOLEAN {

      my Int $i = $!index;
      $!index++;

      %!promises{$key} = Promise.start( {
          my $v = $!encoded-document[$i] ~~ 0x00 ?? False !! True;
          ( $v, $!encoded-document.subbuf($decode-start .. ($i + 1)))
        }
      );
    }

    # Datetime code
    when BSON::C-DATETIME {
      my Int $i = $!index;
      $!index += BSON::C-INT64-SIZE;

      %!promises{$key} = Promise.start( {
          my $v = DateTime.new(
            decode-int64( $!encoded-document, $i) / 1000,
            :timezone(0)
          );

          ( $v, $!encoded-document.subbuf(
                  $decode-start ..^ ($i + BSON::C-INT64-SIZE)
                )
          )
        }
      );
    }

    # Null value -> Any
    when BSON::C-NULL {
      %!promises{$key} = Promise.start( {
          my $i = $!index;
          ( Any, $!encoded-document.subbuf($decode-start ..^ $i))
        }
      );
    }

    # regular expressions. these are perl5 like
    when BSON::C-REGEX {
      my $doc-size = $!encoded-document.elems;
      my $i1 = $!index;
      while $!encoded-document[$!index] !~~ 0x00 and $!index < $doc-size {
        $!index++;
      }
      $!index++;
      my $i2 = $!index;

      while $!encoded-document[$!index] !~~ 0x00 and $!index < $doc-size {
        $!index++;
      }
      $!index++;
      my $i3 = $!index;

      %!promises{$key} = Promise.start( {
          my $v = BSON::Regex.new(
            :regex(decode-cstring( $!encoded-document, $i1)),
            :options(decode-cstring( $!encoded-document, $i2))
          );

          ( $v, $!encoded-document.subbuf($decode-start ..^ $i3))
        }
      );
    }

    # Javascript code
    when BSON::C-JAVASCRIPT {

      # Get the size of the javascript code text, then adjust index
      # for this size and set i for the decoding. Then adjust index again
      # for the next action.
      my Int $i = $!index;
      my Int $buf-size = decode-int32( $!encoded-document, $i);

      # Step over size field and the javascript text
      $!index += (BSON::C-INT32-SIZE + $buf-size);

      %!promises{$key} = Promise.start( {
          my $v = BSON::Javascript.decode( $!encoded-document, $i);

          ( $v, $!encoded-document.subbuf(
                  $decode-start ..^ ($i + BSON::C-INT32-SIZE + $buf-size)
                )
          )
        }
      );
    }

    # Javascript code with scope
    when BSON::C-JAVASCRIPT-SCOPE {

      my Int $i1 = $!index;
      my Int $js-size = decode-int32( $!encoded-document, $i1);
      my Int $i2 = $!index + BSON::C-INT32-SIZE + $js-size;
      my Int $js-scope-size = decode-int32( $!encoded-document, $i2);

      $!index += (BSON::C-INT32-SIZE + $js-size + $js-scope-size);
      my Int $i3 = $!index;

      %!promises{$key} = Promise.start( {
          require ::('BSON::Document');
          my $v = BSON::Javascript.decode(
            $!encoded-document, $i1,
            :bson-doc(::('BSON::Document').new),
            :scope(Buf.new($!encoded-document[$i2 ..^ ($i2 + $js-size)]))
          );

          ( $v, $!encoded-document.subbuf($decode-start ..^ $i3))
        }
      );
    }

    # 32-bit Integer
    when BSON::C-INT32 {

      my Int $i = $!index;
      $!index += BSON::C-INT32-SIZE;

      %!promises{$key} = Promise.start( {
          my $v = decode-int32( $!encoded-document, $i);
#note 'C-INT32:, ', $v;
          ( $v, $!encoded-document.subbuf(
                  $decode-start ..^ ($i + BSON::C-INT32-SIZE)
                )
          )
        }
      );
    }

    # timestamp
    when BSON::C-TIMESTAMP {

      my Int $i = $!index;
      $!index += BSON::C-UINT64-SIZE;

      %!promises{$key} = Promise.start( {
#            @!values[$idx] = BSON::Timestamp.new( :timestamp(
#                decode-uint64( $!encoded-document, $i)
#              )
#            );
          my $v = decode-uint64( $!encoded-document, $i);
#note "Timestamp: ", @!values[$idx];

          ( $v, $!encoded-document.subbuf(
                  $decode-start ..^ ($i + BSON::C-UINT64-SIZE)
                )
          )
        }
      );
    }

    # 64-bit Integer
    when BSON::C-INT64 {

      my Int $i = $!index;
      $!index += BSON::C-INT64-SIZE;

      %!promises{$key} = Promise.start( {
          my $v = decode-int64( $!encoded-document, $i);

          # return value and encoded snippet
          ( $v, $!encoded-document.subbuf(
                  $decode-start ..^ ($i + BSON::C-INT64-SIZE)
                )
          )
        }
      );
    }

    # 128-bit Decimal
    when BSON::C-DECIMAL128 {
      #`{{

      my Int $i = $!index;
      $!index += BSON::C-DECIMAL128-SIZE;

      %!promises{$key} = Promise.start( {
          @!values[$idx] = BSON::Decimal128.decode( $!encoded-document, $i);

          $!encoded-document.subbuf(
            $decode-start ..^ ($i + BSON::C-DECIMAL128-SIZE)
          );
        }
      );
    }}

      die X::BSON.new(
        :operation<decode>, :type($_),
        :error("BSON code '{.fmt('0x%02x')}' not yet implemented"),
      );
    }

    default {
      # We must stop because we do not know what the length should be of
      # this particular structure.
      die X::BSON.new(
        :operation<decode>,
        :error("BSON code '{.fmt('0x%02x')}' not implemented"),
        :type($_)
      );
    } # default
  } # given
} # method

#----------------------------------------------------------------------------
method !process-decode-promises {
#note 'process-decode-promises: ', %!promises.elems, ', ', %!promises.keys;

#    if %!promises.elems {
    await Promise.allof(%!promises.values);
    my $idx = 0;
    for %!promises.keys -> $key {

#        if %!promises{$key}:exists {
        # Return the Buffer slices in each entry so it can be
        # concatenated again when encoding
#note "$*THREAD.id() Before wait for result of $key";
        ( %!document{$key}, @!encoded-entries[$idx]) = %!promises{$key}.result;
#note %!document{$key};
        $idx++;
#note "$*THREAD.id() After wait for $key";
#        } # if
    } # for

#`{{
    loop ( my $idx = 0; $idx < @!keys.elems; $idx++) {
      my $key = @!keys[$idx];
#note "$*THREAD.id() Prom from $key, $idx, {%!promises{$key}:exists}";

      if %!promises{$key}:exists {
        # Return the Buffer slices in each entry so it can be
        # concatenated again when encoding
#note "$*THREAD.id() Before wait for result of $key";
        ( @!values[$idx], @!encoded-entries[$idx]) = %!promises{$key}.result;
#note "$*THREAD.id() After wait for $key";
      } # if
    } # loop
}}

    %!promises = ();
#    } # if
} # method

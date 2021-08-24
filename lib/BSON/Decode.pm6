use v6.d;

use BSON;
use BSON::ObjectId;
use BSON::Binary;
use BSON::Decimal128;
use BSON::Javascript;
use BSON::Regex;
#use BSON::Ordered;
use BSON::Document;

#-------------------------------------------------------------------------------
unit class BSON::Decode:auth<github:MARTIMM>:ver<0.1.0>;
#also does BSON::Ordered;

has UInt $!index = 0;
#has %!promises;
has Buf $!encoded-document;
has Buf @!encoded-entries;

#has $!document;

#-------------------------------------------------------------------------------
#submethod BUILD ( ) {
#}

#-------------------------------------------------------------------------------
method decode ( Buf:D $data --> Any ) {

  my BSON::Document $document .= new;

  $!encoded-document = $data;
  @!encoded-entries = ();

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

  # decode elements until end of doc (last byte of document is 0x00)
#note "index: $!index, $!encoded-document[$!index]";
  while $!encoded-document[$!index] !~~ 0x00 {
    self!decode-element($document);
#note "  ==>> $!index, $!encoded-document[$!index]";
  }

  # step over the last byte: index should now be the doc size
  $!index++;

  # check size of document with final byte location
  die X::BSON.new(
    :operation<decode>, :type<Document>,
    :error(
      [~] 'Size of document(', $doc-size,
          ') does not match with index(', $!index, ')'
    )
  ) if $doc-size != $!index;

  # wait for promises to end for this document
#  self!process-decode-promises;

  $document;
}

#-------------------------------------------------------------------------------
method !decode-element ( BSON::Document $document --> Nil ) {

  # Decode start point
  my $decode-start = $!index;

  # Get the value type of next pair
  my $bson-code = $!encoded-document[$!index++];

  # Get the key value, Index is adjusted to just after the 0x00
  # of the string.
  my Str $key = decode-e-name( $!encoded-document, $!index);
#note "de: $key found, type 0x$bson-code.fmt('%02x'), idx now $!index";

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
#      %!promises{$key} = Promise.start( {
#          my $v = decode-double( $!encoded-document, $i);
#note "DBL: $key, $idx = @!values[$idx]";

          # Return total section of binary data
          $document{$key} = decode-double( $!encoded-document, $i);
          @!encoded-entries[$idx] = $!encoded-document.subbuf(
                  $decode-start ..^            # At bson code
                  ($i + BSON::C-DOUBLE-SIZE)   # $i is at code + key further
                );

#        }
#      );
    }

    # String type
    when BSON::C-STRING {

      my Int $i = $!index;
      my Int $nbr-bytes = decode-int32( $!encoded-document, $!index);

      # Step over the size field and the null terminated string
      $!index += BSON::C-INT32-SIZE + $nbr-bytes;

#      %!promises{$key} = Promise.start( {
          my $v = decode-string( $!encoded-document, $i);

          ( $document{$key}, @!encoded-entries[$idx]) = (
            $v, $!encoded-document.subbuf(
                  $decode-start ..^
                  ($i + BSON::C-INT32-SIZE + $nbr-bytes)
                )
          )
#        }
#      );
    }

    # Nested document
    when BSON::C-DOCUMENT {
      my Int $i = $!index;
      my Int $doc-size = decode-int32( $!encoded-document, $i);

      # Wait for any threads to complete before decoding the subdocument
      # If not, the threads are eaten up and we end up waiting for
      # non-started threads.
#      self!process-decode-promises;

      my BSON::Decode $decoder .= new;
      my BSON::Document $d = $decoder.decode(
        $!encoded-document.subbuf($i ..^ ($i + $doc-size))
      );

#      %!promises{$key} = Promise.start( {
      $document{$key} = $d;
      @!encoded-entries[$idx] = $!encoded-document.subbuf(
        $decode-start ..^ ($i + $doc-size)
      );
#          ( $document{$key}, @!encoded-entries[$idx]) =
#            ( $d, $!encoded-document.subbuf(
#                $decode-start ..^ ($i + $doc-size)
#              )
#            );

      $!index = $i + $doc-size;
#note "BD ds: $!index";
#        }
#      );
    }

    # Array code
    when BSON::C-ARRAY {

      my Int $i = $!index;
      my Int $doc-size = decode-int32( $!encoded-document, $!index);
      $!index += $doc-size;
#note "A: $!index, $doc-size";

#      self!process-decode-promises;
#      %!promises{$key} = Promise.start( {
      my BSON::Decode $decoder .= new;
      my BSON::Document $d = $decoder.decode(
        $!encoded-document.subbuf($i ..^ ($i + $doc-size))
      );

#          my $v = [$d.values];

#          ( $document{$key}, @!encoded-entries[$idx]) =
#            ( $v, $!encoded-document.subbuf( $decode-start ..^ ($i + $doc-size)));

      $document{$key} = [$d.values];
      @!encoded-entries[$idx] = $!encoded-document.subbuf(
        $decode-start ..^ ($i + $doc-size)
      );

      $!index = $i + $doc-size;
#note "A ds: $!index";
#        }
#      );
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

#      %!promises{$key} = Promise.start( {
          my $v = BSON::Binary.decode(
            $!encoded-document, $i, :$buf-size
          );

          ( $document{$key}, @!encoded-entries[$idx]) =
            ( $v, $!encoded-document.subbuf(
                  $decode-start ..^ ($i + 1 + $buf-size)
                )
            )
#        }
#      );
    }

    # Object id
    when BSON::C-OBJECTID {

      my Int $i = $!index;
      $!index += 12;

#      %!promises{$key} = Promise.start( {
          my $v = BSON::ObjectId.decode( $!encoded-document, $i);
          ( $document{$key}, @!encoded-entries[$idx]) = ( $v, $!encoded-document.subbuf($decode-start ..^ ($i + 12)))
#        }
#      );
    }

    # Boolean code
    when BSON::C-BOOLEAN {

      my Int $i = $!index;
      $!index++;

#      %!promises{$key} = Promise.start( {
          my $v = $!encoded-document[$i] ~~ 0x00 ?? False !! True;
          ( $document{$key}, @!encoded-entries[$idx]) = ( $v, $!encoded-document.subbuf($decode-start .. ($i + 1)))
#        }
#      );
    }

    # Datetime code
    when BSON::C-DATETIME {
      my Int $i = $!index;
      $!index += BSON::C-INT64-SIZE;

#      %!promises{$key} = Promise.start( {
          my $v = DateTime.new(
            decode-int64( $!encoded-document, $i) / 1000,
            :timezone(0)
          );

          ( $document{$key}, @!encoded-entries[$idx]) = ( $v, $!encoded-document.subbuf(
                  $decode-start ..^ ($i + BSON::C-INT64-SIZE)
                )
          )
#        }
#      );
    }

    # Null value -> Any
    when BSON::C-NULL {
#      %!promises{$key} = Promise.start( {
          my $i = $!index;
          ( $document{$key}, @!encoded-entries[$idx]) = ( Any, $!encoded-document.subbuf($decode-start ..^ $i))
#        }
#      );
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

#      %!promises{$key} = Promise.start( {
          my $v = BSON::Regex.new(
            :regex(decode-cstring( $!encoded-document, $i1)),
            :options(decode-cstring( $!encoded-document, $i2))
          );

          ( $document{$key}, @!encoded-entries[$idx]) = ( $v, $!encoded-document.subbuf($decode-start ..^ $i3))
#        }
#      );
    }

    # Javascript code
    when BSON::C-JAVASCRIPT {
#note 'C-JAVASCRIPT';

      # Get the size of the javascript code text, then adjust index
      # for this size and set i for the decoding. Then adjust index again
      # for the next action.
      my Int $i = $!index;
      my Int $buf-size = decode-int32( $!encoded-document, $i);

      # Step over size field and the javascript text
      $!index += (BSON::C-INT32-SIZE + $buf-size);

#      %!promises{$key} = Promise.start( {
          my $v = BSON::Javascript.decode( $!encoded-document, $i);

          ( $document{$key}, @!encoded-entries[$idx]) = ( $v, $!encoded-document.subbuf(
                  $decode-start ..^ ($i + BSON::C-INT32-SIZE + $buf-size)
                )
          )
#        }
#      );
    }

    # Javascript code with scope
    when BSON::C-JAVASCRIPT-SCOPE {
#note 'C-JAVASCRIPT-SCOPE';

      my Int $i1 = $!index;
      my Int $js-size = decode-int32( $!encoded-document, $i1);
      my Int $i2 = $!index + BSON::C-INT32-SIZE + $js-size;
      my Int $js-scope-size = decode-int32( $!encoded-document, $i2);

      $!index += (BSON::C-INT32-SIZE + $js-size + $js-scope-size);
      my Int $i3 = $!index;

#      %!promises{$key} = Promise.start( {
          my $v = BSON::Javascript.decode(
            $!encoded-document, $i1,
            :scope(Buf.new($!encoded-document[$i2 ..^ ($i2 + $js-size)])),
            :decoder(BSON::Decode.new)
          );

          ( $document{$key}, @!encoded-entries[$idx]) = ( $v, $!encoded-document.subbuf($decode-start ..^ $i3))
#        }
#      );
    }

    # 32-bit Integer
    when BSON::C-INT32 {

      my Int $i = $!index;
      $!index += BSON::C-INT32-SIZE;

#      %!promises{$key} = Promise.start( {
          my $v = decode-int32( $!encoded-document, $i);
#note $*THREAD.id, ', C-INT32:, ', $v, ', ', $!encoded-document.subbuf($decode-start ..^ ($i + BSON::C-INT32-SIZE));
          ( $document{$key}, @!encoded-entries[$idx]) = ( $v, $!encoded-document.subbuf(
                  $decode-start ..^ ($i + BSON::C-INT32-SIZE)
                )
          )
#        }
#      );
    }

    # timestamp
    when BSON::C-TIMESTAMP {

      my Int $i = $!index;
      $!index += BSON::C-UINT64-SIZE;

#      %!promises{$key} = Promise.start( {
#            @!values[$idx] = BSON::Timestamp.new( :timestamp(
#                decode-uint64( $!encoded-document, $i)
#              )
#            );
          my $v = decode-uint64( $!encoded-document, $i);
#note "Timestamp: ", @!values[$idx];

          ( $document{$key}, @!encoded-entries[$idx]) = ( $v, $!encoded-document.subbuf(
                  $decode-start ..^ ($i + BSON::C-UINT64-SIZE)
                )
          )
#        }
#      );
    }

    # 64-bit Integer
    when BSON::C-INT64 {

      my Int $i = $!index;
      $!index += BSON::C-INT64-SIZE;

#      %!promises{$key} = Promise.start( {
          my $v = decode-int64( $!encoded-document, $i);

          # return value and encoded snippet
          ( $document{$key}, @!encoded-entries[$idx]) = ( $v, $!encoded-document.subbuf(
                  $decode-start ..^ ($i + BSON::C-INT64-SIZE)
                )
          )
#        }
#      );
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

#`{{
#-------------------------------------------------------------------------------
method !process-decode-promises ( ) {
#note 'process-decode-promises: ', %!promises.elems, ', ', %!promises.keys;

  my @k = ();
  my @v = ();

#    if %!promises.elems {
    await Promise.allof(%!promises.values);
    my $idx = 0;
    for %!promises.keys -> $key {

#      if %!promises{$key}:exists {
        # Return the Buffer slices in each entry so it can be
        # concatenated again when encoding
#note "$*THREAD.id() Before wait for result of $key";
        @k[$idx] = $key;
        ( $!document{$key}, @!encoded-entries[$idx]) = %!promises{$key}.result;
note "$*THREAD.id(), $key, $!document{$key}";
        $idx++;
#note "$*THREAD.id() After wait for $key";
#      } # if
    } # for

    for ^$idx -> $i {
      $!document{@k[$i]} = @v[$i];
    }
note $!document;

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
}}

#`{{
#-------------------------------------------------------------------------------
method bytes ( Buf $b --> Str) {
  return $b.Str;

  my Str $bytes = '';
  for @!encoded-entries -> $idx {
    $bytes ~= @!encoded-entries[$idx].gist ~ "\n";
  }

  $bytes
}
}}

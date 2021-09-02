#TL:1:BSON::Decode:

use v6.d;

#-------------------------------------------------------------------------------
=begin pod

=head1 BSON::Decode

Decode binary data from a Buf


=head1 Description

The mongodb server returns data in binary form. This must be decoded to access the document properly.

Note that when using the MongoDB driver package, the driver will handle the encoding and decoding.


=head1 Synopsis
=head2 Declaration

  unit class BSON::Decode:auth<github:MARTIMM>;


=head2 Example

  my BSON::Document $d0 .= new: ( :1bread, :66eggs);
  my Buf $b = BSON::Encode.new.encode($d0);

  …

  my BSON::Document $d1 = BSON::Decode.decode($b);

=end pod

#-------------------------------------------------------------------------------
use BSON;
use BSON::ObjectId;
use BSON::Binary;
use BSON::Decimal128;
use BSON::Javascript;
use BSON::Regex;
use BSON::Document;

#-------------------------------------------------------------------------------
unit class BSON::Decode:auth<github:MARTIMM>:ver<0.2.0>;

has UInt $!index = 0;
has Buf $!encoded-document;
has Buf @!encoded-entries;

#-------------------------------------------------------------------------------
#TM:1:decode
=begin pod
=head1 Methods
=head2 decode

Decode binary data

  method decode ( Buf:D $data --> BSON::Document )

=item Buf $data; the binary data

=end pod

method decode ( Buf:D $data --> BSON::Document ) {

  my BSON::Document $document .= new;

  $!encoded-document = $data;
  @!encoded-entries = ();

  # document decoding start: init index
  $!index = 0;

  # decode the document, then wait for any started parallel tracks
  # first get the size of the (nested-)document
  my Int $doc-size = $!encoded-document.read-int32( $!index, LittleEndian);

  # step to the document content
  $!index += BSON::C-INT32-SIZE;

  # decode elements until end of doc (last byte of document is 0x00)
  while $!encoded-document[$!index] !~~ 0x00 {
    self!decode-element($document);
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

  # Keys are pushed in the proper order as they are seen in the
  # byte buffer.
  my Int $idx = @!encoded-entries.elems;
  my Int $size;

  given $bson-code {

    # 64-bit floating point
    when BSON::C-DOUBLE {

      my Int $i = $!index;
      $!index += BSON::C-DOUBLE-SIZE;

      # Return total section of binary data
      $document{$key} = $!encoded-document.read-num64( $i, LittleEndian);
      @!encoded-entries[$idx] = $!encoded-document.subbuf(
        $decode-start ..^            # At bson code
        ($i + BSON::C-DOUBLE-SIZE)   # $i is at code + key further
      );
    }

    # String type
    when BSON::C-STRING {

      my Int $i = $!index;
      my Int $nbr-bytes = $!encoded-document.read-int32( $!index, LittleEndian);

      # Step over the size field and the null terminated string
      $!index += BSON::C-INT32-SIZE + $nbr-bytes;

      $document{$key} = decode-string( $!encoded-document, $i);
      @!encoded-entries[$idx] = $!encoded-document.subbuf(
        $decode-start ..^ ($i + BSON::C-INT32-SIZE + $nbr-bytes)
      );
    }

    # Nested document
    when BSON::C-DOCUMENT {
      my Int $i = $!index;
      my Int $doc-size = $!encoded-document.read-int32( $i, LittleEndian);

      my BSON::Decode $decoder .= new;
      $document{$key} = $decoder.decode(
        $!encoded-document.subbuf($i ..^ ($i + $doc-size))
      );
      @!encoded-entries[$idx] = $!encoded-document.subbuf(
        $decode-start ..^ ($i + $doc-size)
      );

      $!index = $i + $doc-size;
    }

    # Array code
    when BSON::C-ARRAY {

      my Int $i = $!index;
      my Int $doc-size = $!encoded-document.read-int32( $!index, LittleEndian);
      $!index += $doc-size;

      my BSON::Decode $decoder .= new;
      $document{$key} = [
        $decoder.decode(
          $!encoded-document.subbuf($i ..^ ($i + $doc-size))
        ).values;
      ];
      @!encoded-entries[$idx] = $!encoded-document.subbuf(
        $decode-start ..^ ($i + $doc-size)
      );

      $!index = $i + $doc-size;
    }

    # Binary code
    # "\x05 e_name int32 subtype byte*
    # subtype = byte \x00 .. \x05, .. \xFF
    # subtypes \x80 to \xFF are user defined
    when BSON::C-BINARY {

      my Int $buf-size = $!encoded-document.read-int32( $!index, LittleEndian);
      my Int $i = $!index + BSON::C-INT32-SIZE;

      # Step over size field, subtype and binary data
      $!index += BSON::C-INT32-SIZE + 1 + $buf-size;

      $document{$key} = BSON::Binary.decode(
        $!encoded-document, $i, :$buf-size
      );
      @!encoded-entries[$idx] = $!encoded-document.subbuf(
        $decode-start ..^ ($i + 1 + $buf-size)
      );
    }

    # Object id
    when BSON::C-OBJECTID {

      my Int $i = $!index;
      $!index += 12;

      $document{$key} = BSON::ObjectId.decode( $!encoded-document, $i);
      @!encoded-entries[$idx] = $!encoded-document.subbuf(
        $decode-start ..^ ($i + 12)
      );
    }

    # Boolean code
    when BSON::C-BOOLEAN {

      my Int $i = $!index;
      $!index++;

      $document{$key} = $!encoded-document[$i] ~~ 0x00 ?? False !! True;
      @!encoded-entries[$idx] = $!encoded-document.subbuf(
        $decode-start .. ($i + 1)
      );
    }

    # Datetime code
    when BSON::C-DATETIME {
      my Int $i = $!index;
      $!index += BSON::C-INT64-SIZE;

      $document{$key} = DateTime.new(
        $!encoded-document.read-int64( $i, LittleEndian) / 1000,
        :timezone(0)
      );
      @!encoded-entries[$idx] = $!encoded-document.subbuf(
        $decode-start ..^ ($i + BSON::C-INT64-SIZE)
      );
    }

    # Null value -> Any
    when BSON::C-NULL {
      my $i = $!index;

      $document{$key} = Any;
      @!encoded-entries[$idx] = $!encoded-document.subbuf(
        $decode-start ..^ $i
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

      $document{$key} = BSON::Regex.new(
        :regex(decode-cstring( $!encoded-document, $i1)),
        :options(decode-cstring( $!encoded-document, $i2))
      );
      @!encoded-entries[$idx] = $!encoded-document.subbuf(
        $decode-start ..^ $i3
      );
    }

    # Javascript code
    when BSON::C-JAVASCRIPT {

      # Get the size of the javascript code text, then adjust index
      # for this size and set i for the decoding. Then adjust index again
      # for the next action.
      my Int $i = $!index;
      my Int $buf-size = $!encoded-document.read-int32( $i, LittleEndian);

      # Step over size field and the javascript text
      $!index += (BSON::C-INT32-SIZE + $buf-size);

      $document{$key} = BSON::Javascript.decode( $!encoded-document, $i);
      @!encoded-entries[$idx] = $!encoded-document.subbuf(
        $decode-start ..^ ($i + BSON::C-INT32-SIZE + $buf-size)
      );
    }

    # Javascript code with scope
    when BSON::C-JAVASCRIPT-SCOPE {

      my Int $i1 = $!index;
      my Int $js-size = $!encoded-document.read-int32( $i1, LittleEndian);
      my Int $i2 = $!index + BSON::C-INT32-SIZE + $js-size;
      my Int $js-scope-size = $!encoded-document.read-int32( $i2, LittleEndian);

      $!index += (BSON::C-INT32-SIZE + $js-size + $js-scope-size);
      my Int $i3 = $!index;
      $document{$key} = BSON::Javascript.decode(
        $!encoded-document, $i1,
        :scope(Buf.new($!encoded-document[$i2 ..^ ($i2 + $js-size)])),
        :decoder(BSON::Decode.new)
      );
      @!encoded-entries[$idx] = $!encoded-document.subbuf(
        $decode-start ..^ $i3
      );
    }

    # 32-bit Integer
    when BSON::C-INT32 {

      my Int $i = $!index;
      $!index += BSON::C-INT32-SIZE;

      $document{$key} = $!encoded-document.read-int32( $i, LittleEndian);
      @!encoded-entries[$idx] = $!encoded-document.subbuf(
        $decode-start ..^ ($i + BSON::C-INT32-SIZE)
      )
    }

    # timestamp
    when BSON::C-TIMESTAMP {

      my Int $i = $!index;
      $!index += BSON::C-UINT64-SIZE;

      $document{$key} = $!encoded-document.read-uint64( $i, LittleEndian);
      @!encoded-entries[$idx] = $!encoded-document.subbuf(
        $decode-start ..^ ($i + BSON::C-UINT64-SIZE)
      );
    }

    # 64-bit Integer
    when BSON::C-INT64 {

      my Int $i = $!index;
      $!index += BSON::C-INT64-SIZE;

      $document{$key} = $!encoded-document.read-int64( $i, LittleEndian);
      @!encoded-entries[$idx] = $!encoded-document.subbuf(
        $decode-start ..^ ($i + BSON::C-INT64-SIZE)
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

#TL:1:BSON::Binary:

use v6.d;

#-------------------------------------------------------------------------------
=begin pod

=head1 BSON::Binary

Container for binary data


=head1 Description

The BSON specification describes several types of binary data of which a few are deprecated. In the table below, you can see what is defined and what is supported by this class.

=begin table

SubCode | Constant            | Note
=============================================================================
0x00    | BSON::C-GENERIC     | Generic binary subtype.
0x01    | BSON::C-FUNCTION    | Function.
0x02    | BSON::C-BINARY-OLD  | Binary, deprecated.
0x03    | BSON::C-UUID-OLD    | UUID, deprecated.
0x04    | BSON::C-UUID        | UUID.
0x05    | BSON::C-MD5         | MD5.
0x06    | BSON::C-ENCRIPT     | Encrypted BSON value. This new and not yet implemented.
… 0x7F  |                     | All other codes to 0x80 are reserved.
0x80    |                     | User may define their own code from 0x80 … 0xFF.
0xFF    |                     | End of the range.

=end table

=head1 Synopsis
=head2 Declaration

  unit class BSON::Binary:auth<github:MARTIMM>;


=head2 Example

  # A Universally Unique IDentifier
  my BSON::Document $doc .= new;
  $doc<uuid> = BSON::Binary.new(
    :data(UUID.new(:version(4).Blob)), :type(BSON::C-UUID)
  );

  # My own complex number type. Can be done easier, but well you know,
  # I needed some example …
  enum MyBinDataTypes ( :COMPLEX(0x80), …);
  my Complex $c = 2.4 + 3.3i;
  my Buf $data .= new;
  $data.write-num64( 0, $c.re, LittleEndian);
  $data.write-num64( BSON::C-DOUBLE-SIZE, $c.im, LittleEndian);
  $doc<complex> = BSON::Binary.new( :$data, :type(COMPLEX));


=end pod

#-------------------------------------------------------------------------------
use Method::Also;

use BSON;

#-------------------------------------------------------------------------------
unit class BSON::Binary:auth<github:MARTIMM>:ver<0.2.0>;

#-------------------------------------------------------------------------------
has Buf $.binary-data;
has Bool $.has-binary-data = False;
has Int $.binary-type;

#-------------------------------------------------------------------------------
#TM:1:new
=begin pod
=head1 Methods
=head2 new

Create a container to hold binary data.

  new ( Buf :$data, Int :$type = BSON::C-GENERIC )

=item Buf :$data; the binary data.
=item Int :$type; the type of the data. By default it is set to BSON::C-GENERIC.

=end pod

submethod BUILD ( Buf :$data, Int :$type = BSON::C-GENERIC ) {

  die X::BSON.new(
    :operation("code $type is a reserved binary type"),
    :type($type), :error("Unsupported type")
  ) if ( $type ≥ BSON::C-SPECIFIED ) and ( $type < BSON::C-USERDEFINED-MIN );

  $!binary-data = $data;
  $!has-binary-data = ?$!binary-data;
  $!binary-type = $type;
}

#-------------------------------------------------------------------------------
#TM:1:raku
#TM:1:perl
=begin pod
=head2 raku, perl

Show the structure of a document

  method raku ( Int $indent = 0 --> Str ) is also<perl>

=item Int $indent; setting the starting indentation.

=end pod

method raku ( UInt $indent = 0 --> Str ) is also<perl> {
#  $indent = 0 if $indent < 0;

  my $perl = "BSON::Binary.new(";
  my $bin-i1 = '  ' x ($indent + 1);
  my $bin-i2 = '  ' x ($indent + 2);

  my Str $str-type = <C-GENERIC C-FUNCTION C-BINARY-OLD C-UUID-OLD
                      C-UUID C-MD5 C-ENCRIPT
                     >[$!binary-type];

  if ? $str-type {
    $str-type = "BSON::$str-type";
  }

  else {
#TODO extend with new user types
  }

  $perl ~= "\n$bin-i1\:type\($str-type)";

  if $!binary-data {
    my Str $bstr = $!binary-data.perl;
    $bstr ~~ s:g/ (\d+) (<[,\)]>) /{$0.fmt('0x%02x')}$1/;
    my $nspaces = ($bstr ~~ m:g/\s/).elems;
    for 8,16...Inf -> $space-loc {
      $bstr = $bstr.subst( /\s+/, "\n$bin-i2", :nth($space-loc));
      last if $space-loc > $nspaces;
    }
    $bstr ~~ s/\.new\(/.new(\n$bin-i2/;
    $bstr ~~ s:m/'))'/\n$bin-i1)/;
    $perl ~= ",\n$bin-i1\:data($bstr)\n";
  }

  else {
    $perl ~= "\n" ~ $bin-i1 ~ ")\n";
  }

  $perl ~= '  ' x $indent ~ ")";
}

#-------------------------------------------------------------------------------
#TM:1:encode
=begin pod

Encode a BSON::Binary object. This is called from the BSON::Document encode method.

  method encode ( --> Buf )

=end pod

method encode ( --> Buf ) {
  my Buf $b .= new;
  if self.has-binary-data {
    $b ~= Buf.new.write-int32( 0, self.binary-data.elems, LittleEndian);
    $b ~= Buf.new(self.binary-type);
    $b ~= self.binary-data;
  }

  else {
    $b ~= Buf.new.write-int32( 0, 0, LittleEndian);
    $b ~= Buf.new(self.binary-type);
  }

  $b;
}

#-------------------------------------------------------------------------------
#TM:1:decode
=begin pod

Decode a Buf object. This is called from the BSON::Document decode method.

  method decode (
    Buf:D $b, Int:D $index is copy, Int:D :$buf-size
    --> BSON::Binary
  )

=end pod

method decode (
  Buf:D $b, Int:D $index is copy, Int:D :$buf-size
  --> BSON::Binary
) {

  # Get subtype
  my $sub_type = $b[$index++];

  # Most of the tests are not necessary because of arbitrary sizes.
  # UUID and MD5 can be tested.
  given $sub_type {
    when BSON::C-GENERIC {
      # Generic binary subtype
    }

    when BSON::C-FUNCTION {
      # Function
    }

    when BSON::C-BINARY-OLD {
      # Binary (Old - deprecated)
      die X::BSON.new(
        :operation<decode>, :type(BSON::Binary),
        :error("Type $_ is deprecated")
      );
    }

    when BSON::C-UUID-OLD {
      # UUID (Old - deprecated)
      die X::BSON.new(
        :operation<decode>, :type(BSON::Binary),
        :subtype("Type $_ is deprecated")
      );
    }

    when BSON::C-UUID {
      # UUID. According to
      # http://en.wikipedia.org/wiki/Universally_unique_identifier the
      # universally unique identifier is a 128-bit (16 byte) value.
      #
      die X::BSON.new(
        :operation<decode>, :type<binary>,
        :error('UUID(0x04) Length mismatch')
      ) unless $buf-size ~~ BSON::C-UUID-SIZE;
    }

    when BSON::C-MD5 {
      # MD5. This is a 16 byte number (32 character hex string)
      die X::BSON.new(
        :operation<decode>, :type<binary>,
        :error('MD5(0x05) Length mismatch')
      ) unless $buf-size ~~ BSON::C-MD5-SIZE;
    }

    # when 0x80..0xFF
    default {
      # User defined. That is, all other codes 0x80 .. 0xFF
    }
  }

  BSON::Binary.new(
    :data(Buf.new($b[$index ..^ ($index + $buf-size)])),
    :type($sub_type)
  )
}

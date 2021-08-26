use v6.d;

use Method::Also;

use BSON;

#-------------------------------------------------------------------------------
unit class BSON::Binary:auth<github:MARTIMM>:ver<0.2.0>;

#-------------------------------------------------------------------------------
has Buf $.binary-data;
has Bool $.has-binary-data = False;
has Int $.binary-type;

#-------------------------------------------------------------------------------
submethod BUILD ( Buf :$data, Int :$type = BSON::C-GENERIC ) {
  $!binary-data = $data;
  $!has-binary-data = ?$!binary-data;
  $!binary-type = $type;
}

#-------------------------------------------------------------------------------
method raku ( Int $indent = 0 --> Str ) is also<perl> {
  $indent = 0 if $indent < 0;

  my $perl = "BSON::Binary.new(";
  my $bin-i1 = '  ' x ($indent + 1);
  my $bin-i2 = '  ' x ($indent + 2);

  my Str $str-type = <C-GENERIC C-FUNCTION C-BINARY-OLD C-UUID-OLD
                      C-UUID C-MD5
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
method decode (
  Buf:D $b,
  Int:D $index is copy,
  Int:D :$buf-size
  --> BSON::Binary
) {

  # Get subtype
  #
  my $sub_type = $b[$index++];

  # Most of the tests are not necessary because of arbitrary sizes.
  # UUID and MD5 can be tested.
  #
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

  return BSON::Binary.new(
    :data(Buf.new($b[$index ..^ ($index + $buf-size)])),
    :type($sub_type)
  );
}

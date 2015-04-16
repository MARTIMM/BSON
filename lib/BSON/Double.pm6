use v6;
use BSON::Encodable;

package BSON {
  class Double does BSON::Encodable {

    multi method new( Str :$key_name, :$key_data --> BSON::Double ) {
      return self.bless( :bson_code(0x01), :$key_name, :$key_data);
    }

    method encode( --> Buf ) {

      my Num $r = $!key_data;
      my Buf $a;

      # Test special cases
      #
      # 0x 0000 0000 0000 0000 = 0
      # 0x 8000 0000 0000 0000 = -0       Not recognizable
      # 0x 7ff0 0000 0000 0000 = Inf
      # 0x fff0 0000 0000 0000 = -Inf
      #
      given $r {
        when 0 {
          $a = Buf.new(0 xx 8);
        }

        when -Inf {
          $a = Buf.new( 0 xx 6, 0xF0, 0xFF);
        }

        when Inf {
          $a = Buf.new( 0 xx 6, 0xF0, 0x7F);
        }

        default {
          my Int $sign = $r.sign == -1 ?? -1 !! 1;
#          $r *= $sign;
          $r = -$r unless $sign == 1;

          # Get proper precision from base(2) by first shifting 52 places which
          # is the number of precision bits. Adjust the exponent bias for this.
          #
          my Int $exp-shift = 0;
          my Int $exponent = 1023;
          my Str $bit-string = $r.base(2);
          $bit-string ~= '.' unless $bit-string ~~ m/\./;

          # Smaller than zero
          #
          if $bit-string ~~ m/^0\./ {

            # Normalize
            #
            my $first-one = $bit-string.index('1');
            $exponent -= $first-one - 1;

            # Multiply to get more bits in precision
            #
            while $bit-string ~~ m/^0\./ {    # Starts with 0.
              $exp-shift += 52;               # modify precision
              $r *= 2 ** $exp-shift;          # modify number
              $bit-string = $r.base(2)        # Get bit string again
            }
          }

          # Bigger than zero
          #
          else {
            # Normalize
            #
            my Int $dot-loc = $bit-string.index('.');
            $exponent += $dot-loc - 1;

            # If dot is in the string, not at the end, the precision might
            # be not sufficient. Enlarge one time more
            #
            my Int $str-len = $bit-string.chars;
            if $dot-loc < $str-len - 1 {
              $r *= 2 ** 52;
              $bit-string = $r.base(2)
            }
          }

          $bit-string ~~ s/<[0.]>*$//;            # Remove trailing zeros
          $bit-string ~~ s/\.//;                  # Remove the dot
          my @bits = $bit-string.split('');       # Create array of '1' and '0'
          @bits.shift;                            # Remove the first 1.

          my Int $i = $sign == -1 ?? 0x8000_0000_0000_0000 !! 0;
          $i = $i +| ($exponent +< 52);
          my Int $bit-pattern = 1 +< 51;
          do for @bits -> $bit {
            $i = $i +| $bit-pattern if $bit eq '1';

            $bit-pattern = $bit-pattern +> 1;

            last unless $bit-pattern;
          }

          $a = self!enc_int64($i);
        }
      }

      return $a;
    }

    # We have to do some simulation using the information on
    # http://en.wikipedia.org/wiki/Double-precision_floating-point_format#Endianness
    # until better times come.
    #
    method decode ( List $a ) {

      # Test special cases
      #
      # 0x 0000 0000 0000 0000 = 0
      # 0x 8000 0000 0000 0000 = -0
      # 0x 7ff0 0000 0000 0000 = Inf
      # 0x fff0 0000 0000 0000 = -Inf
      #
      my Bool $six-byte-zeros = True;
      for ^6 -> $i {
        if $a[$i] {
          $six-byte-zeros = False;
          last;
        }
      }

      my Num $value;
      if $six-byte-zeros and $a[6] == 0 {
        if $a[7] == 0 {
          $value .= new(0);
        }

        elsif $a[7] == 0x80 {
          $value .= new(-0);
        }
      }

      elsif $a[6] == 0xF0 {
        if $a[7] == 0x7F {
          $value .= new(Inf);
        }

        elsif $a[7] == 0xFF {
          $value .= new(-Inf);
        }
      }

      # If value is set by the special cases above, remove the 8 bytes from
      # the array.
      #
      if $value.defined {
        $a.splice( 0, 8);
      }

      # If value is not set by the special cases above, calculate it here
      #
      else {
        my Int $i = self!dec_int64( $a );
        my Int $sign = $i +& 0x8000_0000_0000_0000 ?? -1 !! 1;

        # Significand + implicit bit
        #
        my $significand = 0x10_0000_0000_0000 +| ($i +& 0xF_FFFF_FFFF_FFFF);

        # Exponent - bias (1023) - the number of bits for precision
        #
        my $exponent = (($i +& 0x7FF0_0000_0000_0000) +> 52) - 1023 - 52;

        $value = Num.new((2 ** $exponent) * $significand * $sign);
      }

      return $value; #X::NYI.new(feature => "Type Double");
    }
  }
}

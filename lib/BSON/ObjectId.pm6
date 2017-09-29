use v6.c;

#------------------------------------------------------------------------------
unit package BSON:auth<github:MARTIMM>;

use BSON;
use OpenSSL::Digest;

#------------------------------------------------------------------------------
# Information about object id construction can be found at
# http://docs.mongodb.org/manual/reference/object-id/
# Here it will be used when the argument to encode() is undefined.
#
class ObjectId {

  # Represents ObjectId BSON type described in
  # http://dochub.mongodb.org/core/objectids
  #
  has Buf $.oid;

  has Int $.time;
  has Str $.machine-id;
  has Int $.pid;
  has Int $.count;

  #----------------------------------------------------------------------------
  # A string of 24 hexadecimal characters.
  #
  multi submethod BUILD ( Str:D :$string! ) {

    die X::BSON.new(
      :type<ObjectId>, :operation('new()'),
      :error('String too short or nonhexadecimal')
    ) unless $string ~~ m/ ^ <xdigit>**24 $ /;


    $!oid .= new: ($string.comb(/../) ==> map { :16($_) });

    $!time = :16(
      ( $!oid[3...0].list ==> map { $_.fmt('%02x') }
      ).reverse.join('')
    );

    try {
      $!machine-id = (
        $!oid[6...4].list ==> map { $_.fmt('%02x') }
        ).reverse.join('').decode;
      CATCH {
        default {
          $!machine-id = 'Not defined';
        }
      }
    }

    $!pid = :16(
      ( $!oid[8,7].list ==> map { $_.fmt('%02x') }
      ).reverse.join('')
    );

    $!count = :16(
      ( $!oid[11...9].list ==> map { $_.fmt('%02x') }
      ).reverse.join('')
    );
  }

  #----------------------------------------------------------------------------
  # A buffer of 12 bytes
  #
  multi submethod BUILD ( Buf:D :$bytes ) {

    die X::BSON.new(
      :operation('new()'), :type('ObjectId'),
      :error('Byte buffer too short/long')
    ) unless $bytes.elems == 12;

    $!oid = $bytes;

    $!time = :16( ($!oid[0..3].list ==> map { $_.fmt('%02x') }).join('') );

    try {
      $!machine-id = (
        $!oid[4..6].list ==> map { $_.fmt('%02x') }
        ).join('').decode;
      CATCH {

        default {
          $!machine-id = 'No utf-8 encoded machine name';
        }
      }
    }

    $!pid = :16( ($!oid[7..8].list ==> map { $_.fmt('%02x') }).join('') );

    $!count = :16( ($!oid[9..11].list ==> map { $_.fmt('%02x') }).join('') );
  }

  #----------------------------------------------------------------------------
  # Only given a machine name and a count
  # See also: http://docs.mongodb.org/manual/reference/object-id
  #
  multi submethod BUILD ( Str:D :$machine-name!, Int:D :$count! ) {

    $!machine-id = md5($machine-name.encode)>>.fmt('%02x').join('').substr( 0, 6);
    $!time = time;
    $!pid = $*PID;
    $!count = $count;

    self!generate-oid;
  }

  #----------------------------------------------------------------------------
  # No arguments. Generated id.
  # See also: http://docs.mongodb.org/manual/reference/object-id
  #
  multi submethod BUILD ( ) {

    $!machine-id = md5((~$*KERNEL).encode)>>.fmt('%02x').join('').substr( 0, 6);
    $!time = time;
    $!pid = $*PID;
    $!count = 0xFFFFFF.rand.Int;

    self!generate-oid;
  }

  #----------------------------------------------------------------------------
  method perl ( --> Str ) {
    my Str $string = $!oid.list.fmt('%02x');
    $string ~~ s:g/\s+//;
    [~] 'BSON::ObjectId.new(', ":string('0x$string')", ')';
  }

  #----------------------------------------------------------------------------
  method !generate-oid ( ) {

    my @numbers = ();

    # Generate object id
    #
    # Time in 4 bytes => no substr needed
    #
    for $!time.fmt('%08x').comb(/../)[3...0] -> $hexnum {
      @numbers.push: :16($hexnum);
    }

    # Machine id in 3 bytes
    #
    for $!machine-id.fmt('%6.6s').comb(/../)[2...0] -> $hexnum {
      @numbers.push: :16($hexnum);
    }

    # Process id in 2 bytes
    #
    for $!pid.fmt('%04x').comb(/../)[1,0] -> $hexnum {
      @numbers.push: :16($hexnum);
    }

    # Result of count truncated to 3 bytes
    #
    for $!count.fmt('%08x').comb(/../)[2...0] -> $hexnum {
      @numbers.push: :16($hexnum);
    }

    $!oid .= new(@numbers);
  }

  #----------------------------------------------------------------------------
  method encode ( ) {
    $!oid;
  }

  #----------------------------------------------------------------------------
  method decode (
    Buf:D $b,
    Int:D $index is copy,
    --> BSON::ObjectId
  ) {
    BSON::ObjectId.new(:bytes($b[$index ..^ ($index + 12)]));
  }
}

use v6;

#-------------------------------------------------------------------------------
unit package BSON:auth<github:MARTIMM>;

use BSON;
use OpenSSL::Digest;

#-------------------------------------------------------------------------------
# Information about object id construction can be found at
#   http://docs.mongodb.org/manual/reference/object-id
#   https://github.com/mongodb/specifications/blob/master/source/objectid.rst
#
class ObjectId {

  my Int $random-base-per-application-run;

  has Buf $.oid;

  # == ObjectId.getTimestamp()
  has Int $.time;
#  has Str $.machine-id;
  has Int $.pid;
  has Int $.count;

  #-----------------------------------------------------------------------------
  # See also:
  #   http://docs.mongodb.org/manual/reference/object-id
  #   https://github.com/mongodb/specifications/blob/master/source/objectid.rst
  #
  # A string of 24 hexadecimal characters.
  multi submethod BUILD ( Str:D :$string! ) {

    # Check length
    die X::BSON.new(
      :type<ObjectId>, :operation('new()'),
      :error('String too short or nonhexadecimal')
    ) unless $string ~~ m/ ^ <xdigit>**24 $ /;


    # Split into bytes
    $!oid .= new( $string.comb(2).map({ .parse-base(16) }) );
    self.BUILD( :bytes($!oid), :oid-is-set);
  }

  #-----------------------------------------------------------------------------
  # A buffer of 12 bytes. All data is little endian encoded.
  multi submethod BUILD ( Buf:D :$bytes!, Bool :$oid-is-set = False ) {

    die X::BSON.new(
      :operation('new()'), :type('ObjectId'),
      :error('Byte buffer too short/long')
    ) unless $bytes.elems == 12;

    $!oid = $bytes unless $oid-is-set;

    # Time stamp must be little endian encoded in 4 bytes
    $!time = :16( ( $!oid[3...0].map({ $_.fmt('%02x') }) ).reverse.join('') );

    # Machine id is stored together with pid of process. Originally 2 bytes
    # but modern systems take more than that. So machine id now gets 2
    # chars/bytes of the machines os name. The pid will take 3 bytes with a
    # total of this field, 5 bytes.
#    $!machine-id = $!oid[ 4, 5]>>.chr.join;

    $!pid = :16( ( $!oid[6..8].map( { $_.fmt('%02x') } )).join );

    $!count = :16( ( $!oid[9..11].map( { $_.fmt('%02x') } ) ).join );
  }

  #-----------------------------------------------------------------------------
  # Only given a machine name and a count
  multi submethod BUILD (
    Str:D :$machine-name!, Int:D :$count!
  ) is DEPRECATED("one of the other inits") {

#    $!machine-id = $machine-name.substr( 0, 2);
    $!time = time;
    $!pid = $*PID;
    $!count = $count;

    self!generate-oid;
  }

  #-----------------------------------------------------------------------------
  # No arguments. Generated id.
  multi submethod BUILD ( ) {

    # Initialize with first value
    $random-base-per-application-run //= 0xffffff.rand.Int;

    # Machine id of only 2 letters
#    $!machine-id = $*KERNEL.Str.substr( 0, 2);
    $!time = time;
    $!pid = $*PID;
    $!count = $random-base-per-application-run++;

    self!generate-oid;
  }

  #-----------------------------------------------------------------------------
  method perl ( --> Str ) {
    [~] 'BSON::ObjectId.new(', ":string('0x{ self.Str }')", ')'
  }

  #-----------------------------------------------------------------------------
  # == ObjectId.toString()
  method Str ( --> Str ) {
    #my Str $string = $!oid.list.fmt('%02x');
    #$string ~~ s:g/\s+//;
    $!oid>>.fmt('%02x').join;
  }

  #-----------------------------------------------------------------------------
  # Generate object id. All data is little endian encoded.
  method !generate-oid ( ) {

    my @numbers = ();

    # Time in 4 bytes big endian encoded => no substr needed
    @numbers.push: |$!time.fmt('%08x').comb(2)[3...0];

    # Machine id in 2 bytes
#    @numbers.push: |$!machine-id.comb>>.ord>>.base(16);

    # Process id in 5 bytes. On 64 bit systems the pid might be 2²². Look for
    # it in file /proc/sys/kernel/pid_max. => 3 bytes - 2 bits. It is
    # configurable by writing a max into that file, so it can be larger.
    @numbers.push: |($!pid +& 0xFFFFFFFFFF).fmt('%010x').comb(2);

    # Result of count truncated to 3 bytes
    @numbers.push: |($!count +& 0xFFFFFF).fmt('%06x').comb(2);

    $!oid .= new(|@numbers.map({ .parse-base(16) }));
  }

  #-----------------------------------------------------------------------------
  method encode ( --> Buf ) {
    $!oid
  }

  #-----------------------------------------------------------------------------
  method decode ( Buf:D $b, Int:D $index is copy --> BSON::ObjectId ) {
    BSON::ObjectId.new(:bytes(Buf.new($b[ ^12 + $index ])));
  }
}

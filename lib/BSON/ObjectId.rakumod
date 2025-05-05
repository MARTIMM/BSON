#TL:1:BSON::ObjectId:

use v6.d;

#-------------------------------------------------------------------------------
=begin pod

=head1 BSON::ObjectId

Container for Object id.


=head1 Description

Object id's are used by the mongodb server and are added to the document automatically to distinguish documents from each other. When you are looking at your data on a server with, lets say C<robo3t>, you will notice a key named 'C<_id>' with an ObjectId object. For this reason, it is not very usefull to add such an object to your data yourself.


=head1 Synopsis
=head2 Declaration

  unit class BSON::ObjectId:auth<github:MARTIMM>;


=comment head2 Example


=end pod

#-------------------------------------------------------------------------------
use BSON;
use OpenSSL::Digest;
use Method::Also;

#-------------------------------------------------------------------------------
# Information about object id construction can be found at
#   https://docs.mongodb.com/manual/reference/method/ObjectId/
#   https://github.com/mongodb/specifications/blob/master/source/objectid.rst
unit class BSON::ObjectId:auth<github:MARTIMM>:ver<0.2.0>;

use BSON;
use OpenSSL::Digest;
use Method::Also;

#-------------------------------------------------------------------------------
my Int $random-base-per-application-run;

has Buf $.oid;
has Int $.time;
has Int $.random;
has Int $.count;

#-------------------------------------------------------------------------------
#TM:1:new(:string)
#TM:1:new(:bytes)
=begin pod
=head1 Methods
=head2 new

=head3 default, no arguments

Create an ObjectId object. According to the specs, the first 4 bytes is a time stamp encoded as Big Endian. Then a random number of 5 bytes with another 3 byte random number. The last random number is generated once per application run and is incremented everytime a new object id is generated.

=head3 :string

Create an ObjectId object using a hexadecimal string.

  new ( Str:D :$string! )

=item Str :$string; A hexadecimal string of 24 digits

=head3 :bytes

Create an ObjectId object using a 12 byte Buf.

  new ( Buf:D :$bytes! )

=end pod

multi submethod BUILD ( Str:D :$string! ) {

  # Check length
  die X::BSON.new(
    :type<ObjectId>, :operation('new()'),
    :error('String too short or nonhexadecimal')
  ) unless $string ~~ m/^ <xdigit>**24 $/;

  # Split into bytes
  $!oid .= new( $string.comb(2).map({ .parse-base(16) }) );
#  self.BUILD(:bytes($!oid));

  # Get information from the oid. First a time stamp, must be big endian
  # encoded in 4 bytes
  $!time = $!oid.read-int32( 0, BigEndian);

  # Followed by a 5 byte random number
  $!random = :16( ( $!oid[4..8].map( { $_.fmt('%02x') } )).join );

  # Followed by a 3 byte random number
  $!count = :16( ( $!oid[9..11].map( { $_.fmt('%02x') } )).join );
}

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# A buffer of 12 bytes. All data is little endian encoded.
multi submethod BUILD ( Buf:D :$bytes! ) {

  die X::BSON.new(
    :operation('new()'), :type('ObjectId'),
    :error('Byte buffer too short/long')
  ) unless $bytes.elems == 12;

  $!oid = $bytes;

  # Get information from the oid. First a time stamp, must be big endian
  # encoded in 4 bytes
  $!time = $!oid.read-int32( 0, BigEndian);

  # Followed by a 5 byte random number
  $!random = :16( ( $!oid[4..8].map( { $_.fmt('%02x') } )).join );

  # Followed by a 3 byte random number
  $!count = :16( ( $!oid[9..11].map( { $_.fmt('%02x') } )).join );
}

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Only given a machine name and a count
multi submethod BUILD (
  Str:D :$machine-name!, Int:D :$count!
) is DEPRECATED("one of the other inits") {

  $!time = time;
  $!random = 0xffffffffff.rand.Int;
  $!count = $count;

  self!generate-oid;
}

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# No arguments. Generated id.
multi submethod BUILD ( ) {

  # Initialize with first value
  $random-base-per-application-run //= 0xffffff.rand.Int;

  $!time = time;
  $!random = 0xffffffffff.rand.Int;
  $!count = $random-base-per-application-run++;

  self!generate-oid;
}

#-------------------------------------------------------------------------------
#TM:1:raku
#TM:1:perl
=begin pod
=head2 raku, perl

Show the structure of a document

  method raku ( Int :$indent --> Str ) is also<perl>

=end pod

method raku ( UInt :$indent --> Str ) is also<perl> {
  [~] 'BSON::ObjectId.new(', ":string<{ self.Str }>", ')'
}

#-------------------------------------------------------------------------------
#TM:1:Str
#TM:1:to-string
=begin pod
=head2 Str, to-string

Return a 24 digit hexadecimal string

  method Str ( --> Str ) is also<to-string>

=end pod

method Str ( --> Str ) is also<to-string> {
  #my Str $string = $!oid.list.fmt('%02x');
  #$string ~~ s:g/\s+//;
  $!oid>>.fmt('%02x').join;
}

#-------------------------------------------------------------------------------
method get-timestamp ( --> Int ) {
  $!time
}

#-------------------------------------------------------------------------------
# Generate object id. All data is little endian encoded.
method !generate-oid ( ) {

  my @numbers = ();

  # Time in 4 bytes big endian encoded => no substr needed
  @numbers.push: |$!time.fmt('%08x').comb(2)[3...0];

#`{{ Old! Now only random in 5 bytes
  # Process id in 5 bytes. On 64 bit systems the pid might be 2²². Look for
  # it in file /proc/sys/kernel/pid_max. => 3 bytes - 2 bits. It is
  # configurable by writing a max into that file, so it can be larger.
}}
  @numbers.push: |($!random +& 0xFFFFFFFFFF).fmt('%010x').comb(2);

  # Result of count truncated to 3 bytes
  @numbers.push: |($!count +& 0xFFFFFF).fmt('%06x').comb(2);

  $!oid .= new(|@numbers.map({ .parse-base(16) }));
}

#-------------------------------------------------------------------------------
#TM:1:encode
=begin pod
=head2 encode

Encode a BSON::ObjectId object. This is called from the BSON::Document encode method.

  method encode ( --> Buf )

=end pod

method encode ( --> Buf ) {
  $!oid
}

#-------------------------------------------------------------------------------
#TM:1:decode
=begin pod
=head2 decode

Decode a Buf object. This is called from the BSON::Document decode method.

  method decode (
    Buf:D $b, Int:D $index is copy
    --> BSON::ObjectId
  )

=item Buf $b; the binary data
=item Int $index; index into a larger document where object id binary starts

=end pod

method decode ( Buf:D $b, Int:D $index is copy --> BSON::ObjectId ) {
  BSON::ObjectId.new(:bytes(Buf.new($b[ ^12 + $index ])));
}

#TL:1:BSON::Javascript:

use v6.d;

#-------------------------------------------------------------------------------
=begin pod

=head1 BSON::Javascript

Container for Javascript code.


=head1 Description

Javascript can be run on a mongodb server so there is a type for it. This class acts as a container for Javascript. There are two ways to specify this; Javascript with or without a scope. The scope variant is deprecated in the mean time in the BSON specification but still implemented in this code. Better not to use it however.

Examples of the use of Javascript is L<found here|https://docs.mongodb.com/manual/reference/command/mapReduce/#mongodb-dbcommand-dbcmd.mapReduce>. The operation explained here is about the C<mapReduce> run command.

Be aware that, according to L<this story|https://docs.mongodb.com/manual/tutorial/map-reduce-examples/>, that using an aggregation pipeline provides better performance in some cases. This link provides also a few examples of the mapReduce operation.


=head1 Synopsis
=head2 Declaration

  unit class BSON::Javascript:auth<github:MARTIMM>;


=head2 Example

  my BSON::Document $d .= new;
  $d<javascript> = BSON::Javascript.new(
    :javascript('function(x){return x;}')
  );


=end pod

#-------------------------------------------------------------------------------
use Method::Also;

use BSON;

#-------------------------------------------------------------------------------
unit class BSON::Javascript:auth<github:MARTIMM>:ver<0.2.1>;

has Str $.javascript;
has $.scope;
has Buf $!encoded-scope;

has Bool $.has-javascript = False;
has Bool $.has-scope = False;


#-------------------------------------------------------------------------------
#TM:1:new
=begin pod
=head1 Methods
=head2 new

Create a Javascript object

  new ( Str :$javascript, BSON::Document :$scope? )

=item Str :$javascript; the javascript code
=item BSON::Document :$scope; Optional scope to provide variables

=end pod

submethod BUILD (
  Str :$!javascript,
  :$!scope where (.^name eq 'BSON::Document' or $_ ~~ Any)
) {

  $!has-javascript = ?$!javascript;
  $!has-scope = ?$!scope;
  $!encoded-scope = $!scope.encode if $!has-scope;
}

#-------------------------------------------------------------------------------
#TM:1:raku
#TM:1:perl
=begin pod

Show the structure of a document

  method raku ( Int :$indent --> Str ) is also<perl>

=end pod

method raku ( UInt :$indent = 0 --> Str ) is also<perl> {

  my Str $perl = "BSON::Javascript.new\(";
  my $jvs-i1 = '  ' x ($indent + 1);
  my $jvs-i2 = '  ' x ($indent + 2);
  if $!javascript {
    $perl ~= "\n$jvs-i1\:javascript\(\n";
    $perl ~= (map {$jvs-i2 ~ $_}, $!javascript.lines).join("\n");
    $perl ~= "\n$jvs-i1)";

    if $!scope {
      $perl ~= ",\n";
    }

    else {
      $perl ~= "\n";
    }
  }

  if ?$!scope {
    $perl ~= [~] $jvs-i1, ':scope(',
             $!scope.raku(:indent($indent + 2), :no-end);
    $perl ~= $jvs-i1 ~ ")\n";
  }

  $perl ~= '  ' x $indent ~ ")";
}

#-------------------------------------------------------------------------------
#method of ( ) {
#  BSON::Javascript;
#}

#-------------------------------------------------------------------------------
#TM:1:encode
=begin pod
=head2 encode

Encode a BSON::Javascript object. This is called from the BSON::Document encode method.

  method encode ( --> Buf )

=end pod

method encode ( --> Buf ) {
  my Buf $js;
  if $!has-javascript {
    $js = encode-string($!javascript);
    $js ~= $!encoded-scope if $!has-scope;
  }

  else {
    die X::BSON.new(
      :operation<encode>, :type<Javscript>,
      :error('cannot process empty javascript code')
    );
  }

  $js
}

#-------------------------------------------------------------------------------
#TM:1:decode
=begin pod
=head2 decode

Decode a Buf object. This is called from the BSON::Document decode method.

  method decode (
    Buf:D $b, Int:D $index is copy, Buf :$scope, :$decoder
    --> BSON::Javascript
  )

=item Buf $b; the binary data
=item Int $index; index into a larger document where binary starts
=item Buf $scope; Optional scope to decode
=item BSON::Decode $decoder; A decoder for the scope to decode.

=end pod

method decode (
  Buf:D $b, Int:D $index is copy, Buf :$scope, :$decoder
  --> BSON::Javascript
) {

  my $js;
  if ?$scope {
    $js = BSON::Javascript.new(
      :javascript( decode-string( $b, $index)), :scope($decoder.decode($scope))
    );
  }

  else {
    $js = BSON::Javascript.new( :javascript( decode-string( $b, $index)));
  }
}

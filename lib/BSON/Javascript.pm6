use v6;

use Method::Also;

use BSON;

#-------------------------------------------------------------------------------
unit class BSON::Javascript:auth<github:MARTIMM>:ver<0.2.0>;

has Str $.javascript;
has $.scope;
has Buf $!encoded-scope;

has Bool $.has-javascript = False;
has Bool $.has-scope = False;

#-------------------------------------------------------------------------------
submethod BUILD (
  Str :$!javascript,
  :$!scope where (.^name eq 'BSON::Document' or $_ ~~ Any)
) {

  $!has-javascript = ?$!javascript;
  $!has-scope = ?$!scope;
  $!encoded-scope = $!scope.encode if $!has-scope;
}

#-------------------------------------------------------------------------------
method raku ( Int $indent is copy = 0 --> Str ) is also<perl> {
  $indent = 0 if $indent < 0;

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

  if $!scope {
    $indent++;
    $perl ~= $jvs-i1 ~ ":scope\(\n{$!scope.raku(:$indent)}";
    $perl ~= $jvs-i1 ~ ")\n";
    $indent--;
  }

  $perl ~= '  ' x $indent ~ ")";
}

#-------------------------------------------------------------------------------
method of ( ) {
  BSON::Javascript;
}

#-------------------------------------------------------------------------------
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
method decode (
  Buf:D $b, Int:D $index is copy, Buf :$scope, :$decoder
  --> BSON::Javascript
) {

  my $js;
  if ?$scope {
#    require ::('BSON::Decode');
#    my $decoder =  ::('BSON::Decode').new;
    $js = BSON::Javascript.new(
      :javascript( decode-string( $b, $index)), :scope($decoder.decode($scope))
    );
  }

  else {
    $js = BSON::Javascript.new( :javascript( decode-string( $b, $index)));
  }
}

use v6;

package X {
  constant MIN = 3;
  constant MAX = 11;
}

=begin pod
=head1 Foo

  method a( Str :$string --> Str )

=end pod

my $a = 10;
a(
  :string<abc>
) if X::MIN <= $a < X::MAX;

=begin pod
=head1 Bar

  method a( Str :$string --> Str )

another bla bla

=end pod

sub a ( Str :$string --> Str ) {
  say $string;
  $string;
}

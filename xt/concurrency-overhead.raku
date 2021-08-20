use v6;

my @a;
my $t0 = now;
for ^200 {
  @a = ();
  for ^1000 -> $i {
    @a[$i] = Promise.start( {
        my $x = $i**4;
        $x *= π - e;
        $x *= 2 / (π - e);
        $x *= 3 / (π - e);
        $x
      }
    );
  }
}

await @a;
my $tdiff = now - $t0;

note @a[3].result;
note "n=200, tt = $tdiff, tm = {$tdiff/200}";



$t0 = now;
for ^200 {
  @a = ();
  for ^1000 -> $i {
    my $x = $i**4;
    $x *= π - e;
    $x *= 2 / (π - e);
    $x *= 3 / (π - e);
    @a[$i] = $x;
  }
}

$tdiff = now - $t0;

note @a[3];
note "n=200, tt = $tdiff, tm = {$tdiff/200}";

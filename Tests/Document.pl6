#!/usr/bin/env perl6

use v6;
use Bench;


say "\nHash order...";
my Hash $h;
for 'a' ... 'z' -> $c {
  $h{$c} = rand * time;
}

for $h.kv -> $k, $v {
  say "$k => $v";
}


say "\nMap order...";
my Map $m;
for 'a' ... 'z' -> $c {
  $m{$c} = rand * time;
}

for $m.kv -> $k, $v {
  say "$k => $v";
}



#class Document does Associative {
class Document does Associative {
  has Array $!keys .= new;
  has Array $!values .= new;

  #-----------------------------------------------------------------------------
  multi method AT-KEY ( Str $key --> Mu ) is rw {

    my $value;
    loop ( my $i = 0; $i < $!keys.elems; $i++ ) {
      if $!keys[$i] ~~ $key {
#say "AT-KEY: modify $key";
        $value := $!values[$i];
        last;
      }
    }

#say "AT-KEY: $i, {$!keys.elems} new key $key";
    if $i == $!keys.elems {
      $!keys[$i] = $key;
      $!values[$i] = '';
      $value := $!values[$i];
    }

#say "V: $value";
    $value;
  }

  #-----------------------------------------------------------------------------
  multi method EXISTS-KEY ( Str $key --> Bool ) {

say "EXISTS-KEY: $key";
    for $!keys -> $k {
      return True if $k ~~ $key;
    }

    return False;
  }

  #-----------------------------------------------------------------------------
  multi method DELETE-KEY ( Str $key --> Bool ) {

say "DELETE-KEY: $key";
    loop ( my $i = 0; $i < $!keys.elems; $i++ ) {
      if $!keys[$i] ~~ $key {
        $!keys.splice( $i, 1);
        $!values.splice( $i, 1);
        last;
      }
    }
  }

  #-----------------------------------------------------------------------------
  multi method kv ( --> List ) {

    ($!keys Z $!values).flat.list;
  }

  #-----------------------------------------------------------------------------
  multi method keys ( --> List ) {

    $!keys.list;
  }

#  multi method ASSIGN-KEY ( $key, $value --> )
}

# Solution with @ instead of Array
#
class Document2 does Associative {
  has @!keys;
  has @!values;

  #-----------------------------------------------------------------------------
  multi method AT-KEY ( Str $key --> Mu ) is rw {

    my $value;
    loop ( my $i = 0; $i < @!keys.elems; $i++ ) {
      if @!keys[$i] ~~ $key {
#say "AT-KEY: modify $key";
        $value := @!values[$i];
        last;
      }
    }

#say "AT-KEY: $i, {@!keys.elems} new key $key";
    if $i == @!keys.elems {
      @!keys[$i] = $key;
      @!values[$i] = '';
      $value := @!values[$i];
    }

#say "V: $value";
    $value;
  }

  #-----------------------------------------------------------------------------
  multi method EXISTS-KEY ( Str $key --> Bool ) {

say "EXISTS-KEY: $key";
    for @!keys -> $k {
      return True if $k ~~ $key;
    }

    return False;
  }

  #-----------------------------------------------------------------------------
  multi method DELETE-KEY ( Str $key --> Bool ) {

say "DELETE-KEY: $key";
    loop ( my $i = 0; $i < @!keys.elems; $i++ ) {
      if @!keys[$i] ~~ $key {
        @!keys.splice( $i, 1);
        @!values.splice( $i, 1);
        last;
      }
    }
  }

  #-----------------------------------------------------------------------------
  multi method kv ( --> List ) {

    (@!keys Z @!values).flat.list;
  }

  #-----------------------------------------------------------------------------
  multi method keys ( --> List ) {

    @!keys.list;
  }

#  multi method ASSIGN-KEY ( $key, $value --> )
}

say "\nDocument order...";

my Document $d .= new;
for 'a' ... 'z' -> $c {
  $d{$c} = rand * time;
}

say "";
say "Keys a, b: ", $d<a b>, ', ', $d{'g'};

for $d.kv -> $k, $v {
  say "$k => $v";
}

say "";

for $d.keys -> $k {
  say "$k => $d{$k}";
  last if $k eq 'k';
}



my $b = Bench.new;
$b.timethese(
  200, {
    filling1_200x2x26 => sub {
      my Document $d .= new;
      for 'aa' ... 'bz' -> $c {
        $d{$c} = 1;
      }
    },
    
    filling2_200x2x26 => sub {
      my Document2 $d .= new;
      for 'aa' ... 'bz' -> $c {
        $d{$c} = 1;
      }
    },
    
    filling3_200x2x26 => sub {
      my Hash $d .= new;
      for 'aa' ... 'bz' -> $c {
        $d{$c} = 1;
      }
    },
  }
);
















=finish

multi method postcircumfix:<{ }>(
  Document $container: **@keys,
  :$k, :$v, :$kv, :$p, :$exists, :$delete
) {

  say "pci: $container, **@keys, $k, $v";

#  @!p.push: $k => $v;
}



  has Int $idx = 0;
  method pull-one ( --> Mu ) {
    $idx < @!p.elems ?? @!p[$idx++] !! IterationEnd;
  }

  method push-exactly ( Document:D $target, Int $count --> Mu ) {
    if @!p.elems - $idx > $count {
      for ^$count {
        if $idx < @!p.elems {
          $target.push: @!p[$idx++];
        }
      }

      $count;
    }

    else {
      IterationEnd;
    }
  }

  method push-at-least ( Document:D $target, Int $count --> Mu ) {
    if @!p.elems - $idx > $count {
      for ^$count {
        if $idx < @!p.elems {
          $target.push: @!p[$idx++];
        }
      }

      $count;
    }

    else {
      IterationEnd;
    }
  }

  method iterator ( ) {

  }

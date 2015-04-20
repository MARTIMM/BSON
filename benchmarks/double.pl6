#!/usr/bin/env perl6
#
use v6;
BEGIN {
  unshift @*INC, '/home/marcel/Languages/Perl6/Projects/BSON/lib';
}

use Bench;
use BSON;
use BSON::Double;

my $bench = Bench.new;
my $bson = BSON.new;

my $v-lt1 = Num.new(1/3);
my $v-gt1 = Num.new(12.3/2.456);
my $v-inf = Inf;
my $v-mnf = -Inf;
my $v-nul = Num.new(0.0);

my BSON::Double $bd-lt1 .= new( :key_name('var-lt1'), :key_data($v-lt1));
my BSON::Double $bd-gt1 .= new( :key_name('var-gt1'), :key_data($v-gt1));
my BSON::Double $bd-inf .= new( :key_name('var-inf'), :key_data($v-inf));
my BSON::Double $bd-mnf .= new( :key_name('var-mnf'), :key_data($v-mnf));
my BSON::Double $bd-nul .= new( :key_name('var-nul'), :key_data($v-nul));

my Buf $b-lt1 = Buf.new(0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xD5, 0x3F);
my Buf $b-gt1 = Buf.new(0x7A, 0xDA, 0x1E, 0xB9, 0x56, 0x08, 0x14, 0x40);
my Buf $b-inf = Buf.new(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x7F);
my Buf $b-mnf = Buf.new(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0xFF);
my Buf $b-nul = Buf.new(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00);

#$bench.timethese( 1000,
#  { obj-e-nul => sub { return $bd-nul.encode; },
#  }
#);

#exit(0);

$bench.timethese( 1000,
  { bson-d-lt1 => sub { return $bson._dec_double($b-lt1.list); },
    bson-d-gt1 => sub { return $bson._dec_double($b-gt1.list); },
    bson-d-inf => sub { return $bson._dec_double($b-inf.list); },
    bson-d-mnf => sub { return $bson._dec_double($b-mnf.list); },
    bson-d-nul => sub { return $bson._dec_double($b-nul.list); },

    bson-e-lt1 => sub { return $bson._enc_double($v-lt1); },
    bson-e-gt1 => sub { return $bson._enc_double($v-gt1); },
    bson-e-inf => sub { return $bson._enc_double($v-inf); },
    bson-e-inf => sub { return $bson._enc_double($v-mnf); },
    bson-e-nul => sub { return $bson._enc_double($v-nul); },

    obj-d-lt1 => sub { return $bd-lt1.decode($b-lt1.list); },
    obj-d-gt1 => sub { return $bd-gt1.decode($b-gt1.list); },
    obj-d-inf => sub { return $bd-inf.decode($b-inf.list); },
    obj-d-mnf => sub { return $bd-mnf.decode($b-mnf.list); },
    obj-d-nul => sub { return $bd-nul.decode($b-nul.list); },

    obj-e-lt1 => sub { return $bd-lt1.encode; },
    obj-e-gt1 => sub { return $bd-gt1.encode; },
    obj-e-inf => sub { return $bd-inf.encode; },
    obj-e-mnf => sub { return $bd-mnf.encode; },
    obj-e-nul => sub { return $bd-nul.encode; },
  }
);

#`{{
--------------------------------------------------------------------------------
2015 04 17 BSON:ver<0.9.2>

Timing 1000 iterations of decode1a, decode1b, decode2a, decode2b, encode1a, encode1b, encode2a, encode2b...
bson-d-gt1: 0.0870 wallclock secs @ 11494.8112/s (n=1000)
bson-d-inf: 0.5648 wallclock secs @ 1770.3843/s (n=1000)
bson-d-lt1: 0.0662 wallclock secs @ 15113.5623/s (n=1000)
bson-d-mnf: 0.5625 wallclock secs @ 1777.6998/s (n=1000)
bson-d-nul: 0.5583 wallclock secs @ 1791.1902/s (n=1000)
bson-e-gt1: 3.1676 wallclock secs @ 315.6995/s (n=1000)
bson-e-inf: 0.0865 wallclock secs @ 11565.0024/s (n=1000)
bson-e-lt1: 3.1786 wallclock secs @ 314.6054/s (n=1000)
bson-e-nul: 0.0426 wallclock secs @ 23475.5695/s (n=1000)
 obj-d-gt1: 0.0835 wallclock secs @ 11976.8050/s (n=1000)
 obj-d-inf: 0.5779 wallclock secs @ 1730.3083/s (n=1000)
 obj-d-lt1: 0.0803 wallclock secs @ 12449.8632/s (n=1000)
 obj-d-mnf: 0.5922 wallclock secs @ 1688.7545/s (n=1000)
 obj-d-nul: 0.5753 wallclock secs @ 1738.2804/s (n=1000)
 obj-e-gt1: 3.4131 wallclock secs @ 292.9893/s (n=1000)
 obj-e-inf: 0.0933 wallclock secs @ 10715.8199/s (n=1000)
 obj-e-lt1: 4.2394 wallclock secs @ 235.8813/s (n=1000)
 obj-e-mnf: 0.0883 wallclock secs @ 11327.6430/s (n=1000)
 obj-e-nul: 0.0411 wallclock secs @ 24337.3836/s (n=1000)
--------------------------------------------------------------------------------
}}


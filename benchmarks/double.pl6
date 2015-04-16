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

my BSON::Double $bd .= new( :key_name('var1'), :key_data(Num.new(0.3)));

my Buf $b = Buf.new(0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xD5, 0x3F);

#my $bmr = $bench.cmpthese( 1000,
$bench.cmpthese( 1000,
  { decode1 => sub { return $bson._dec_double($b.list); },
    encode1 => sub { return $bson._enc_double(Num.new(0.3)); },
    decode2 => sub { return $bd.decode($b.list);},
    encode2 => sub { return $bd.encode;}
  }
);

#say $bmr;
#say "\n", $bmr.^methods;
#say "\n", $bmr.^attributes;

#`{{
--------------------------------------------------------------------------------
2015 04 16 BSON:ver<0.9.2>

Timing 1000 iterations of decode1, decode2, encode1, encode2...
   decode1: 0.0735 wallclock secs @ 13608.0697/s (n=1000)
   decode2: 0.0817 wallclock secs @ 12236.3940/s (n=1000)
   encode1: 4.0758 wallclock secs @ 245.3521/s (n=1000)
   encode2: 4.1264 wallclock secs @ 242.3398/s (n=1000)
O---------O---------O---------O---------O---------O---------O
|         | Rate    | decode1 | decode2 | encode1 | encode2 |
O=========O=========O=========O=========O=========O=========O
| decode1 | 13608/s | --      | 11%     | 5446%   | 5515%   |
| decode2 | 12236/s | -10%    | --      | 4887%   | 4949%   |
| encode1 | 245/s   | -98%    | -98%    | --      | 1%      |
| encode2 | 242/s   | -98%    | -98%    | -1%     | --      |
-------------------------------------------------------------
--------------------------------------------------------------------------------
}}


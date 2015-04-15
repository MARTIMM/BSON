#!/usr/bin/env perl6
#
use v6;
BEGIN {
  unshift @*INC, '/home/marcel/Languages/Perl6/Projects/BSON/lib';
}

use Bench;
use BSON;

my $bench = Bench.new;
my $bson = BSON.new;

my Buf $b = Buf.new(0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xD5, 0x3F);

say $bench.cmpthese( 10000,
  { decode => sub { return $bson._dec_double($b.list); },
    encode => sub { return $bson._enc_double(Num.new(0.3)); }
  }
);

#`{{
--------------------------------------------------------------------------------
2015 04 14 BSON:ver<0.9.2>
Timing 10000 iterations of decode, encode...
    decode: 0.6671 wallclock secs @ 14990.7080/s (n=10000)
    encode: 39.1464 wallclock secs @ 255.4516/s (n=10000)
O--------O---------O--------O--------O
|        | Rate    | decode | encode |
O========O=========O========O========O
| decode | 14991/s | --     | 5768%  |
| encode | 255/s   | -98%   | --     |
--------------------------------------
--------------------------------------------------------------------------------
}}


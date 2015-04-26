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
1) 2015 04 17 BSON:ver<0.9.2>
2) Rakudo perl6 upgrade

Timing 1000 iterations

           Wallclock Seconds
Test Name        1      2      3
----------  ------ ------ ------
bson-d-gt1: 0.0870 0.0750 0.0836 
bson-d-inf: 0.5648 0.5945 0.5580 
bson-d-lt1: 0.0662 0.0775 0.0746 
bson-d-mnf: 0.5625 0.5665 0.5510 
bson-d-nul: 0.5583 0.5563 0.5482 
bson-e-gt1: 3.1676 3.1933 3.1169 
bson-e-inf: 0.0865 0.0870 0.0727 
bson-e-lt1: 3.1786 3.2541 3.1134 
bson-e-nul: 0.0426 0.0421 0.0414 
 obj-d-gt1: 0.0835 0.0970 0.0959 
 obj-d-inf: 0.5779 0.5788 0.5659 
 obj-d-lt1: 0.0803 0.0917 0.0786 
 obj-d-mnf: 0.5922 0.5822 0.5648 
 obj-d-nul: 0.5753 0.5859 0.5650 
 obj-e-gt1: 3.4131 3.2603 3.1599 
 obj-e-inf: 0.0933 0.0910 0.0876 
 obj-e-lt1: 4.2394 3.2889 3.1800 
 obj-e-mnf: 0.0883 0.0769 0.0756 
 obj-e-nul: 0.0411 0.0199 0.0433 
--------------------------------------------------------------------------------
}}










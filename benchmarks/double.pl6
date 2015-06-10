#!/usr/bin/env perl6
#
use v6;
BEGIN {
  say "Remove BEGIN if not running in developers env"
        unless '/home/marcel/Languages'.IO ~~ :d;
  unshift @*INC, '/home/marcel/Languages/Perl6/Projects/BSON/lib';
}

use Bench;
use BSON;
#use BSON::Double;
use BSON::EDC;

my $bench = Bench.new;
my $bson = BSON.new;

# Num variables
#
my $v-lt1 = Num.new(1/3);
my $v-gt1 = Num.new(12.3/2.456);
my $v-inf = Inf;
my $v-mnf = -Inf;
my $v-nul = Num.new(0.0);

# Hashes
#
my Hash $h-lt1 = {test => $v-lt1};
my Hash $h-gt1 = {test => $v-gt1};
my Hash $h-inf = {test => $v-inf};
my Hash $h-mnf = {test => $v-mnf};
my Hash $h-nul = {test => Num.new(0.0)};

# Objects
#
my BSON::Encodable $e .= new;

#my BSON::Encodable $bd-lt1 .= new( :key_name('var-lt1'), :key_data($v-lt1));
#my BSON::Encodable $bd-gt1 .= new( :key_name('var-gt1'), :key_data($v-gt1));
#my BSON::Encodable $bd-inf .= new( :key_name('var-inf'), :key_data($v-inf));
#my BSON::Encodable $bd-mnf .= new( :key_name('var-mnf'), :key_data($v-mnf));
#my BSON::Encodable $bd-nul .= new( :key_name('var-nul'), :key_data($v-nul));

# $v counterparts, encoded numbers
#
my Buf $prfix = Buf.new( 0x13, 0x00 xx 3,                       # Doc size
                         0x01, 0x74, 0x65, 0x73, 0x74, 0x00     # 'test' + 0
                       );
my Buf $b-lt1 = [~] $prfix,
                    Buf.new( 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xD5, 0x3F),
                    Buf.new(0x00);                              # Doc end = '0'
my Buf $b-gt1 = [~] $prfix,
                    Buf.new( 0x7A, 0xDA, 0x1E, 0xB9, 0x56, 0x08, 0x14, 0x40),
                    Buf.new(0x00);
my Buf $b-inf = [~] $prfix,
                    Buf.new( 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x7F),
                    Buf.new(0x00);
my Buf $b-mnf = [~] $prfix,
                    Buf.new( 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0xFF),
                    Buf.new(0x00);
my Buf $b-nul = [~] $prfix,
                    Buf.new( 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00),
                    Buf.new(0x00);

#$bench.timethese( 1000,
#  { obj-e-nul => sub { return $bd-nul.encode; },
#  }
#);

#exit(0);

$bench.timethese( 1000,
  { bson-d-lt1 => sub { return $bson.decode($b-lt1); },
    bson-d-gt1 => sub { return $bson.decode($b-gt1); },
    bson-d-inf => sub { return $bson.decode($b-inf); },
    bson-d-mnf => sub { return $bson.decode($b-mnf); },
    bson-d-nul => sub { return $bson.decode($b-nul); },

    bson-e-lt1 => sub { return $bson.encode($h-lt1); },
    bson-e-gt1 => sub { return $bson.encode($h-gt1); },
    bson-e-inf => sub { return $bson.encode($h-inf); },
    bson-e-inf => sub { return $bson.encode($h-mnf); },
    bson-e-nul => sub { return $bson.encode($h-nul); },

    obj-d-lt1 => sub { return $e.decode($b-lt1); },
    obj-d-gt1 => sub { return $e.decode($b-gt1); },
    obj-d-inf => sub { return $e.decode($b-inf); },
    obj-d-mnf => sub { return $e.decode($b-mnf); },
    obj-d-nul => sub { return $e.decode($b-nul); },

    obj-e-lt1 => sub { return $e.encode($h-lt1); },
    obj-e-gt1 => sub { return $e.encode($h-gt1); },
    obj-e-inf => sub { return $e.encode($h-inf); },
    obj-e-mnf => sub { return $e.encode($h-mnf); },
    obj-e-nul => sub { return $e.encode($h-nul); },
  }
);

#`{{
--------------------------------------------------------------------------------
1) 2015 04 17 BSON:ver<0.9.2>
2) Rakudo perl6 upgrade
3) 2015 04 27 BSON:ver<0.9.3>, Substitute of 2 ** 52 with 4503599627370496
   in obj.
4) Complete translation of process in obj and $bson using _dec_element instead
   of _dec_double. Makes it slower obviously because it does more.
5) A complete transformation of document to stream and back using BSON encode()
   and decode() compared to new classes and roles in files EDC.pm6 and D.pm6.
   Again total time is slower because more work needed to be done.
6) Rakudo upgrade, Big changes

Timing 1000 iterations

           Wallclock Seconds
Test Name        1      2      3      4      5      6
----------  ------ ------ ------ ------ ------ ------
bson-d-gt1: 0.0870 0.0750 0.0836 0.1808 0.3141 0.5323
bson-d-inf: 0.5648 0.5945 0.5580 0.6783 0.8511 0.4402
bson-d-lt1: 0.0662 0.0775 0.0746 0.1685 0.3066 0.4887
bson-d-mnf: 0.5625 0.5665 0.5510 0.6705 0.7769 0.4468
bson-d-nul: 0.5583 0.5563 0.5482 0.6669 0.7921 0.4715
bson-e-gt1: 3.1676 3.1933 3.1169 3.2935 3.7345 4.0442
bson-e-inf: 0.0865 0.0870 0.0727 0.2170 0.5872 0.6709
bson-e-lt1: 3.1786 3.2541 3.1134 3.3125 3.7025 4.1637
bson-e-nul: 0.0426 0.0421 0.0414 0.1650 0.5513 0.6178
 obj-d-gt1: 0.0835 0.0970 0.0959 0.2042 0.6716 0.8574
 obj-d-inf: 0.5779 0.5788 0.5659 0.6806 1.1306 0.7859
 obj-d-lt1: 0.0803 0.0917 0.0786 0.2007 0.6929 0.8096
 obj-d-mnf: 0.5922 0.5822 0.5648 0.7014 1.1523 0.8172
 obj-d-nul: 0.5753 0.5859 0.5650 0.6936 1.1296 0.8198
 obj-e-gt1: 3.4131 3.2603 3.1599 3.4228 3.8772 5.3582
 obj-e-inf: 0.0933 0.0910 0.0876 0.2805 0.7803 1.0920
 obj-e-lt1: 4.2394 3.2889 3.1800 3.4766 4.0491 5.5069
 obj-e-mnf: 0.0883 0.0769 0.0756 0.2690 0.8070 1.0946
 obj-e-nul: 0.0411 0.0199 0.0433 0.2389 0.7678 1.0166
--------------------------------------------------------------------------------
}}


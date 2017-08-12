#!/usr/bin/env perl6

use v6;
use lib './Test';

use Bench;
use BSON::Document;

my BSON::Document $d;
my Buf $buf;

my $b = Bench.new;
$b.timethese(
  3000, {
    'insert of 32 bit int with Promise' => sub {
      $d .= new;
      $d<int> = 0x7fffffff;
      $buf = $d.encode;
      $d .= new($buf);
    },
    'insert of 64 bit int with Promise' => sub {
      $d .= new;
      $d<int> = 0x7fffffff_ffffffff;
      $buf = $d.encode;
      $d .= new($buf);
    },
  }
);

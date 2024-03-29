#!/usr/bin/env perl6

use v6;
use lib '/home/marcel/Languages/Raku/Projects/BSON/xt/Test',
        '/home/marcel/Languages/Raku/Projects/BSON/lib';

use Bench;
use BSON::Document;
use BSON::Javascript;
use BSON::Binary;
use BSON::Regex;
use BSON::ObjectId;
use BSON::Encode;
use BSON::Decode;
use UUID;

my BSON::Encode $encoder;
my BSON::Decode $decoder;

my BSON::Javascript $js .= new(
  :javascript('function(x){return x;}')
);

my BSON::Javascript $js-scope .= new(
  :javascript('function(x){return x;}'),
  :scope(BSON::Document.new: (nn => 10, a1 => 2))
);

my UUID $uuid .= new(:version(4));
my BSON::Binary $bin .= new(
  :data($uuid.Blob),
  :type(BSON::C-UUID)
);

my BSON::ObjectId $oid .= new;

my DateTime $datetime .= now;

my BSON::Regex $rex .= new( :regex('abc|def'), :options<is>);

#my $c = 0;
my $b = Bench.new;
$b.timethese(
  500, {
    '32 inserts' => sub {
      my BSON::Document $d .= new;
#say "C: ", $c++;
      $d<b> = -203.345.Num;
      $d<a> = 1234;
      $d<v> = 4295392664;
      $d<w> = $js;
      $d<abcdef> = a1 => 10, bb => 11;
      $d<abcdef><b1> = q => 255;
      $d<jss> = $js-scope;
      $d<bin> = $bin;
      $d<bf> = False;
      $d<bt> = True;
      $d<str> = "String text";
      $d<array> = [ 10, 'abc', 345];
      $d<oid> = $oid;
      $d<dtime> = $datetime;
      $d<null> = Any;
      $d<rex> = $rex;

      # same set but other keys
      $d<ab> = -203.345.Num;
      $d<aa> = 1234;
      $d<av> = 4295392664;
      $d<aw> = $js;
      $d<aabcdef> = a1 => 10, bb => 11;
      $d<aabcdef><b1> = q => 255;
      $d<ajss> = $js-scope;
      $d<abin> = $bin;
      $d<abf> = False;
      $d<abt> = True;
      $d<astr> = "String text";
      $d<aarray> = [ 10, 'abc', 345];
      $d<aoid> = $oid;
      $d<adtime> = $datetime;
      $d<anull> = Any;
      $d<arex> = $rex;

#note "\nDoc; ", '-' x 75, $d.raku, '-' x 80;

      $encoder .= new;
      my Buf $b = $encoder.encode($d);

      $decoder .= new;
      my BSON::Document $d2 = $decoder.decode($b);

#note 'encode';
#exit(0);
#note 'decode';
#      $d2.decode($b);
    }
  }
);

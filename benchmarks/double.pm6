#!/usr/bin/env perl6

use v6.c;
use BSON::Document;

my $ntests = 3000;
my Buf $b;
my Num $n;


my $tt-encode = 0;
for ^$ntests {

  my $t0 = now;

  $b = BSON::Document::encode-double-emulated(-203.345.Num);

  $tt-encode += now - $t0;
}

say "$ntests runs total time = $tt-encode.fmt('%.6f') s,",
    " {($tt-encode/$ntests).fmt('%.6f')} s per run,",
    " {($ntests/$tt-encode).fmt('%.6f')} runs per s";

#say "B: ", $b.list.fmt('%02x');



$tt-encode = 0;
for ^$ntests {

  my $t0 = now;

  $b = encode-double(-203.345.Num);

  $tt-encode += now - $t0;
}

say "$ntests runs total time = $tt-encode.fmt('%.6f') s,",
    " {($tt-encode/$ntests).fmt('%.6f')} s per run,",
    " {($ntests/$tt-encode).fmt('%.6f')} runs per s";

#say "B: ", $b.list.fmt('%02x');




my $tt-decode = 0;
for ^$ntests {

  my $t0 = now;

  $n = BSON::Document::decode-double-emulated( $b, 0);

  $tt-decode += now - $t0;
}

say "$ntests runs total time = $tt-decode.fmt('%.6f') s,",
    " {($tt-decode/$ntests).fmt('%.6f')} s per run,",
    " {($ntests/$tt-decode).fmt('%.6f')} runs per s";


$tt-decode = 0;
for ^$ntests {

  my $t0 = now;

  $n = decode-double( $b, 0);

  $tt-decode += now - $t0;
}

say "$ntests runs total time = $tt-decode.fmt('%.6f') s,",
    " {($tt-decode/$ntests).fmt('%.6f')} s per run,",
    " {($ntests/$tt-decode).fmt('%.6f')} runs per s";




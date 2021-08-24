[toc]

# Benchmark tests

The benchmark tests are setup to follow the improvement in speed while encoding and decoding a document.

## Benchmarks on specific types
### Num types in `double.pm6`

Timing 3000 iterations ....

| Date | What | n per sec |
|------|------|-----------|
| 20160420 | rakudo 2016.02-136-g412d9a4, MoarVM 2016.02-25-gada3752
|| double emulated encode | 396.5552
|| double emulated decode | 2452.2613
|| double native encode | 1464.7237
|| double native decode | 3239.1732
| 20170812 | rakudo 2017.07-91-g7e08f74 built on MoarVM 2017.07-15-g0729f84
|| double emulated encode | 621.9242
|| double emulated decode | 12066.0512
|| double native encode | 8758.5662
|| double native decode | 11083.7616

Conclusion: it is not worth to keep the emulated encode/decode for double (Num). The emulated code was the original implementation before NativeCall was explored.


### Int types in `int.pl6`

Timing 3000 iterations ...

32re: n per sec for 32 bit integer encode
32rd: n per sec for 32 bit integer decode
32nd: n per sec for 32 bit native integer decode
64re: n per sec for 64 bit integer encode
64rd: n per sec for 64 bit integer decode
64nd: n per sec for 64 bit native integer decode

pv1: rakudo 2017.07-91-g7e08f74, MoarVM 2017.07-15-g0729f84
pv2: v2021.07-7-gb7f088b5a, MoarVM 2021.07-8-g860cc6550

| Date     | What | 32re | 32rd | 32nd | 64re | 64rd | 64nd
|----------|------|------|------|------|------|------|------|
| 20170812 | pv1  | 32494| 62385| 22999| 26438| 50397| 21226

Conclusion: it is not worth to do native decode for any type of integer.
note 20210809; seems to be slower, what happened?

## Benchmark documents with only one type

While promises are used to speedup the tests a little, some other tests are devised to look into the difference per BSON type. I imagine that some of the types are so simple to encode/decode that setting up a thread for the calculations would take more overhead than that it would speed up. These tests are made to find out if some types can be taken out of the concurrent setup because the overhead of setting up a thread might take longer than encoding or decoding that particular type.


### Int types in `bench-doc-int.pl6`
Timing 2000 iterations ...

| Date | What | n per sec |
|------|------|-----------|
| 20170813 | rakudo 2017.07-91-g7e08f74, MoarVM 2017.07-15-g0729f84
|| 32 bit int with Promise encode | 900.8279
|| 32 bit int with Promise decode | 935.3248
|| 64 bit int with Promise encode | 839.7693
|| 64 bit int with Promise decode | 927.0989


## Document encoding/decoding, bench-document.pl6

Tests of encoding two series of 16 types, inserted into a newly created document. Then the result is decoded again.


### Test notes and measurements
Timing 50 iterations ...

| Date     | What                                                | n per sec |N
|----------|-----------------------------------------------------|-----------|-|
|| With use of Promises on encoding as well as decoding          |   6.19    |1
|| Removed Promises on decoding (dropped)                        |   5.21
|| After some cleanup of D1                                      |   7.13
|| Replaced Hash $!data with @!values in D1                      |   7.17
|| Replaced %!promises with @!promises (dropped)                 |   6.90
|| Optional use of autovivify and hashes, restorage of buf parts |   4.42
|| A few methods modified into subs                              |   5.27
|| Removing Positional role (dropped)                            |   4.96
|| Bugfixes and improvements. Perl 2015 12 24                    |   6.39
|| Native encoding/decoding for doubles                          |   7.71
| 20160610 |                                                     |  18.0     |2
| 20161108 |                                                     |  19.8     |3
| 20170225 |                                                     |  21.0     |4
| 20170225 | Dropped positional role from BSON::Document         |  21.7
| 20170718 | bugfix hangup decoding                              |  14.7     |5
| 20171101 | 2017.10-25-gbaed02bf7 MoarVM 2017.10, lot of fixes  |  15.9
| 20210809 | v2021.07-7-gb7f088b5a, MoarVM 2021.07-8-g860cc6550  |  42.0     |6
| 20210811 | improve encoding and decoding                       |  46.5
| 20210824 | rewrite and refactor Document. No concurrency.      |  46.2     |7
|          |                                                     |  46.6     |8

1) perl6 versions unknown
2) perl6 2016.06-178-gf7c6e60, MoarVM 2016.06-9-g8fc21d5
3) perl6 2016.10-204-g824b29f, MoarVM 2016.10-37-gf769569
4) rakudo 017.02-56-g9f10434, MoarVM 2017.02-7-g3d85900
5) rakudo 2017.07-19-g1818ad2
6) 500 iterations, rakudo v2021.07-7-gb7f088b5a, MoarVM 2021.07-8-g860cc6550
7) V0.13.0, Concurrency is gone. Although there is no speed improvement, the code is much cleaner.
8) 𝐑𝐚𝐤𝐮𝐝𝐨™ v2021.08-1-g5c74b4053, MoarVM version 2021.08

###  Original BSON methods with hashes.
* I think this was about 2015 06 or so. In the mean time Hashing should be faster too!
  3.1644 wallclock secs @ 15.8006/s (n=50)

[toc]

# Benchmark tests

The benchmark tests are setup to follow the improvement in speed while encoding and decoding a document. While promises are used to speedup the tests a little, some other tests are devised to look into the difference per BSON type. I imagine that some of the types are so simple to encode/decode that setting up a thread for the calculations would take more overhead than that it would speed up.

## Document encoding/decoding

Tests of encoding two series of 16 types, inserted into a newly created document. Then the result is decoded again. This is repeated 50 times.

### Test notes and measurements
* With use of Promises on encoding as well as decoding
  8.0726 wallclock secs @ 6.1938/s (n=50)

* Removed Promises on decoding -> dustbin
  9.5953 wallclock secs @ 5.2109/s (n=50) Slower without Promise

* After some cleanup of D1
  7.0094 wallclock secs @ 7.1333/s (n=50) Cleanup improved speed

* Replaced Hash $!data with @!values in D1
  6.9710 wallclock secs @ 7.1726/s (n=50)

* Replaced %!promises with @!promises -> dustbin
  7.2508 wallclock secs @ 6.8958/s (n=50) Slower with @!promises

* Optional use of autovivify and hashes, restorage of buf parts.
  11.3167 wallclock secs @ 4.4182/s (n=50) Terrible slow

* A few methods modified into subs
  9.4807 wallclock secs @ 5.2739/s (n=50) Small changes

* Removing Positional role -> dustbin
  10.0837 wallclock secs @ 4.9585/s (n=50) Doen't help much

* Bugfixes and improvements
  7.8202 wallclock secs @ 6.3937/s (n=50) Perl 2015 12 24

* Native encoding/decoding for doubles
  6.4880 wallclock secs @ 7.7066/s (n=50) again a bit better

* version 2016.06-178-gf7c6e60 built on MoarVM version 2016.06-9-g8fc21d5
  2.7751 wallclock secs @ 18.0171/s (n=50) big improvement

* 2016-11-08, 2016.10-204-g824b29f built on MoarVM version 2016.10-37-gf769569
  2.5247 wallclock secs @ 19.8041/s (n=50) +

* 2017-02-25. 017.02-56-g9f10434 built on MoarVM version 2017.02-7-g3d85900
  2.3827 wallclock secs @ 20.9844/s (n=50) +

* 2017-02-25. Dropped positional role from BSON::Document.
  2.3011 wallclock secs @ 21.7285/s (n=50) +

* 2017-07-18, 2017.07-19-g1818ad2, bugfix hangup decoding.
  3.3968 wallclock secs @ 14.7199/s (n=50) - step back?


###  Original BSON methods with hashes.
* I think this was about 2015 06 or so. In the mean time Hashing should be faster too!
  3.1644 wallclock secs @ 15.8006/s (n=50)


### Worries
- D14 sometimes crashes with coredumps. Is it Bench or BSON::Document??
Segmentation fault (core dumped)
- Same for D15 when a lot of debug messages were put in. Using --ll-exception
the crash went away. Also inhibiting the debug messages did hide the crash.



## benchmarks double.pm6

### 2016 04 20
   Rakudo version 2016.02-136-g412d9a4
   MoarVM version 2016.02-25-gada3752 implementing Perl 6.c.

* emulated encode
  3000 runs total time = 7.565150 s, 0.002522 s per run, 396.555238 runs per s

* native encode
  3000 runs total time = 2.048168 s, 0.000683 s per run, 1464.723704 runs per s

* emulated decode
  3000 runs total time = 1.223361 s, 0.000408 s per run, 2452.261307 runs per s

* native decode
  3000 runs total time = 0.926162 s, 0.000309 s per run, 3239.173228 runs per s


## benchmarks int64.pm6

### 2016 04 20
   Rakudo version 2016.02-136-g412d9a4
   MoarVM version 2016.02-25-gada3752 implementing Perl 6.c.

*  emulated encode
   3000 runs total time = 0.856549 s, 0.000286 s per run, 3502.425992 runs per s

*  native encode
   3000 runs total time = 1.764482 s, 0.000588 s per run, 1700.215580 runs per s

*  emulated decode
   3000 runs total time = 0.703039 s, 0.000234 s per run, 4267.190570 runs per s

*  native decode
   3000 runs total time = 1.040393 s, 0.000347 s per run, 2883.526640 runs per s

Conclusion: it is not worth to do native encode/decode for any type of integer.

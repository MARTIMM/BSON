Tests of 2 * 16 types of insertions and repeated 50 times



Timing 50 iterations of 32 inserts... (* is current BSON::Document use) 

 D1 T1   With use of Promises on encoding as well as decoding
*D  T2   After some cleanup
 D2 T3   Removed Promises on decoding
 H  T4   Original BSON methods with hashes


 D1 T1  8.0726 wallclock secs @ 6.1938/s (n=50)
*D  T2  7.0094 wallclock secs @ 7.1333/s (n=50)         Cleanup improved speed
 D1 T3  9.5953 wallclock secs @ 5.2109/s (n=50)         Slower without Promise
 H  T4  3.1644 wallclock secs @ 15.8006/s (n=50)


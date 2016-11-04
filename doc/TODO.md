# Bugs, known limitations and todo

* Lack of other Perl 6 types support,
* Change die() statements in return with exception to notify caller and place further responsability there. This is done for Document.pm6
* Perl 6 Int variables are integral numbers of arbitrary size. This means that any integer can be stored as large or small as you like. Int can be coded as described in version 0.8.4 and when larger or smaller then maybe it is possible the Int can be coded as a binary array of some type.
* BUG. An array in a document which is modified later with push, pop or otherwise will not be properly encoded.

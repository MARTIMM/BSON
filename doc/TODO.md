# Bugs, known limitations and todo

### Todo

* [ ] Lack of other Raku types support
* [ ] Change die() statements to use X::BSON exceptions to notify caller and place further responsability there. This is done for `Document.rakumod`.
* [ ] Raku Int variables are integral numbers of arbitrary size. This means that any integer can be stored as large or small as you like. Int is encoded as described in version 0.8.4 (i.e. int32 or int64). When integers get larger or smaller then 64 bits can describe, then the Int should be encoded as a binary array of some type.
* [ ] Support for decimal 128 type = BSON type ID 0x13.
* [ ] Tests some more exceptions of Binary
* [ ] Better checks for wrong sizes of buffers along every type encountered
* [ ] Modify timestamp (en/de)coding to be an object
* [ ] The exception objects are subject to change into a simpler class: one instead of several. This will become **X::BSON**.
* [x] change raku source code file extensions
* [ ] Use the ordered hash of Raku. Some time ago there were problems and decided to go the way I have done it, see also [issue 2](https://github.com/lizmat/Hash-Ordered/issues/2)


### Decimal128

Range: a max value of approximately **10 \*\* 6145**, and min value of approximately **-10 \*\* 6145**

Clamping or Clipping, or clipping [definition](https://en.wikipedia.org/wiki/Clamp_(function)).
  max(minimum, min(x, maximum))

Mongo DB Spec for [Decimal128]( https://github.com/mongodb/specifications/blob/master/source/bson-decimal128/decimal128.md)

[Decimal Arithmetic Encodings](https://speleotrove.com/decimal/decbits.html)
[Exceptional conditions](https://speleotrove.com/decimal/daexcep.html)
[English Wikipedia](https://en.wikipedia.org/wiki/Decimal128_floating-point_format)

#### Raku thoughts
  * FatRat can easily hold very large numbers
  ```
  > 9.2.FatRat**61450
  … 7687684894340881135564919470832634062321093549747941293271363354624
  ```
  * The class **BSON::Decimal128** has functions `.get-value` and `.set-value` to get and set the value of the object. The type used is **Numeric** to be able to cope with `NaN` and `Inf`. `NaN` and `Inf` is only of type **Num**, so it needs special handling when in other types. _This is the responsability of the user._

  * From the raku documentation: "The value Inf is an instance of Num and represents value that's too large to represent in 64-bit double-precision floating point number (roughly, above 1.7976931348623158e308 for positive Inf and below -1.7976931348623157e308 for negative Inf) as well as returned from certain operations as defined by the IEEE 754-2008 standard.". This means that officially `Inf` may be smaller than the max of Decimal128.

#### Specification
Specification of Decimal128 can be found [here](https://speleotrove.com/decimal/dbspec.html) and [here English Wikipedia](https://en.wikipedia.org/wiki/Decimal128_floating-point_format).

* Fields in the Decimal128
  | Use | bits |
  |-|-|
  Sign | 1
  Combination field | 17
  significand continuation | 111 .. 113

* Layout of combination field.
  MSB: most significant bit
  MSD: most significant digit
  | Exponent MSBs | Coefficient MSD | Combination field | Meaning |
  |-|-|-|-|
  | a b |	0 c d e | a b c d e … 12 bits |	Finite
  | c d |	1 0 0 e | 1 1 c d e … 12 bits |	Finite
  | - - |	- - - - | 1 1 1 1 0 … 12 bits |	Infinity
  | 0 - | - - - - | 1 1 1 1 1 … 12 bits |	quiet NaN
  | 1 - | - - - - | 1 1 1 1 1 … 12 bits |	signalling NaN
  
* Significant field
  
  | First 2 bits | Exponent field | Significant field |
  |-|-|-|
  | 00, 01, 10 | 14 bits after sign bit¹ | 113 bits |
  | 11 | 14 bits shifted 2 bits to the right² | 111 bits |

  1) there is an implicit leading 0 bit
  2) there are 3 implicit leading 100 bits



  

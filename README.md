# ![Face](logotype/logo_32x32.png) BSON support

Implements [BSON specification][spec].

<!--
![Face](logotype/logo_32x32.png) [![Build Status](https://travis-ci.org/MARTIMM/BSON.svg?branch=master)](https://travis-ci.org/MARTIMM/BSON) [![AppVeyor Build Status](https://ci.appveyor.com/api/projects/status/github/MARTIMM/bson?branch=master&passingText=Windows%20-%20OK&failingText=Windows%20-%20FAIL&pendingText=Windows%20-%20pending&svg=true)](https://ci.appveyor.com/project/MARTIMM/bson/branch/master) [![License](http://martimm.github.io/label/License-label.svg)](http://www.perlfoundation.org/artistic_license_2_0)

![T][travis-svg] ![A][appveyor-svg]

[travis-svg]: https://travis-ci.com/MARTIMM/BSON.svg?branch=master
[travis-run]: https://travis-ci.com/MARTIMM/BSON

[appveyor-svg]: https://ci.appveyor.com/api/projects/status/github/MARTIMM/BSON?branch=master&passingText=Windows%20-%20OK&failingText=Windows%20-%20FAIL&pendingText=Windows%20-%20pending&svg=true
[appveyor-run]: https://ci.appveyor.com/project/MARTIMM/BSON/branch/master

-->

![L][license-svg]

[license-svg]: https://martimm.github.io/label/License-label.svg
[licence-lnk]: https://www.perlfoundation.org/artistic_license_2_0


## Synopsis

The main entry point is  **BSON::Document**. This structure is a Hash like object but will keep the order of its keys and because of that there is no need for cumbersome operations. At the moment it is much slower than the hashed variant even with the encoding happening in the background and parallel.

```
use BSON::Document;

my BSON::Javascript $js .= new(:javascript('function(x){return x;}'));
my BSON::Javascript $js-scope .= new(
  :javascript('function(x){return x;}'),
  :scope(BSON::Document.new: (nn => 10, a1 => 2))
);

my BSON::Binary $bin .= new(:data(Buf,new(... some binary data ...));
my BSON::Regex $rex .= new( :regex('abc|def'), :options<is>);

my BSON::Document $d .= new: ( 'a number' => 10, 'some text' => 'bla die bla');
$d<oid> = BSON::ObjectId.new;
$d<javascript> = $js;
$d<js-scope> = $js-scope;
$d<datetime> = DateTime.now;
$d<bin> = $bin;
$d<rex> = $rex;
$d<null> = Any;
$d<array> = [ 10, 'abc', 345];
$d<subdoc1> = a1 => 10, bb => 11;
$d<subdoc1><b1> = q => 255;

my Buf $enc-doc = $d.encode;

my BSON::Document $new-doc .= new;
$new-doc.decode($enc-doc);

```

## Documentation

BSON/Document.pod
* [ 🔗 Website]()<!--https://martimm.github.io/raku-mongodb-driver/-->
* [ 🔗 License document][licence-lnk]
* [ 🔗 Release notes](https://github.com/MARTIMM/BSON/blob/main/doc/CHANGES.md)
* [ 🔗 Issues](https://github.com/MARTIMM/BSON/issues)

<!--
* [BSON::Binary][Binary]
* [BSON::Document][Document]

* [Release notes][notes]
* [Bugs, todo][todo]
-->


## Installing BSON

Use zef to install the package like so.
```
$ zef install BSON
```

When installing MongoDB, BSON will be installed automatically as a dependency.

## Version of Raku and MoarVM

This module is tested using the latest 6.d Raku version on MoarVM


## Authors

Original creator of the modules is Pawel Pabian (2011-2015, v0.3)(bbkr on github).
Current maintainer Marcel Timmerman (2015-present)(MARTIMM on github).

## Contributors

Dan Zwell (lefth on github)




[spec]: http://bsonspec.org/

[Binary]: https://github.com/MARTIMM/BSON/blob/master/doc/Binary.pdf
[Document]: https://github.com/MARTIMM/BSON/blob/master/doc/Document.pdf

[notes]: https://github.com/MARTIMM/BSON/blob/master/doc/CHANGES.md
[todo]: https://github.com/MARTIMM/BSON/blob/master/doc/TODO.md

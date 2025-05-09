# BSON Types

List of types and their Raku types.

| BSON type | BSON Code | Raku type |
|-----------|------|-----------|
 double             | 0x01 | Num
 string             | 0x02 | Str
 document           | 0x03 | BSON::Document
 array              | 0x04 | Array
 binary             | 0x05 | BSON::Binary
 undefined¹         | 0x06 |
 objectid           | 0x07 | BSON::ObjectId
 boolean            | 0x08 | Bool
 datetime           | 0x09 | DateTime
 null               | 0x0A | when not defined
 regex              | 0x0B | BSON::Regex
 dbpointer¹         | 0x0C |
 javascript         | 0x0D | BSON::Javascript
 deprecated¹        | 0x0E |
 javascript-scope   | 0x0F | BSON::Javascript
 int32              | 0x10 | Int²
 timestamp          | 0x11 | BSON::Timestamp
 int64              | 0x12 | Int²
 decimal128         | 0x13 | BSON::Decimal128

1) Deprecated bson type
2) Dies when Int does not fit in an int32 or int64


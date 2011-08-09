BEGIN { @*INC.unshift( 'lib' ) }

use Test;
use BSON;

plan( 1 );

"€".bytes.say;
ok( 1, 'test' );

BSON.new.encode({"ala"=>"kot"}).contents.perl.say;

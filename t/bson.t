BEGIN { @*INC.unshift( 'lib' ) }

use Test;

plan( 1 );

lives_ok
    {
        use BSON;
        use BSON::ObjectId;
    },
    'Class loading';

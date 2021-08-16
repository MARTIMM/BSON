use v6;
use Test;
#use NativeCall;

use BSON::Document;

#-------------------------------------------------------------------------------
subtest "Hash errors", {
  my BSON::Document $d;
  throws-like {
    $d .= new(%(:q(20), :p<h>));
    is $d<q><a>, 20, "Hash value $d<q><a>";
  }, X::BSON, 'Arguments cannot be Hash',
  :message(/:s Arguments cannot be Hash/);

  throws-like {
    $d .= new;
    $d<q> = %(a => 20);
    is $d<q><a>, 20, "Hash value $d<q><a>";
  }, X::BSON, 'Cannot use hashes when assigning',
  :message(/:s Cannot use hashes when assigning/);
}



#-------------------------------------------------------------------------------
done-testing;
=finish

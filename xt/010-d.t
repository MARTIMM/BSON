use Test;
use BSON::Document;

#-------------------------------------------------------------------------------
subtest 'empty doc', {

  my BSON::Document $d .= new;
  my Buf $b = $d.encode;
  say $b;
};

#-------------------------------------------------------------------------------
subtest 'empty array', {

  my BSON::Document $d .= new: (
    documents => []
  );

  my Buf $b = $d.encode;
  say $b;

};


#-------------------------------------------------------------------------------
done-testing;

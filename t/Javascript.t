use v6;
use Test;
use BSON;
use BSON::Document;
use BSON::Javascript;

#-------------------------------------------------------------------------------
subtest "Javacsript", {

  my Str $javascript = 'function(x){return x;}';
  my BSON::Javascript $js .= new(:$javascript);
#note $js.raku;

  my BSON::Document $d1 .= new: (:$js,);
#note "\nDoc; ", '-' x 75, $d1.raku, '-' x 80;
  my Buf $b1 = $d1.encode;
  my Buf $b2 =
    [~] Buf.new(0x0D),                              # BSON javascript
       'js'.encode, Buf.new(0x00),                  # 'js'
        Buf.new.write-int32(0, $javascript.chars + 1, LittleEndian),
          $javascript.encode, Buf.new(0x00),        # javascript code
        Buf.new(0x00);                              # end of document
                                                    # prepend size to b2
  is-deeply Buf.new.write-int32( 0, $b2.elems + 4, LittleEndian) ~ $b2, $b1,
            'check encoded javascript';

  my BSON::Document $d2 .= new($b1);
#note "\nDoc; ", '-' x 75, $d2.raku, '-' x 80;
  is-deeply $d1<js>, $d2<js>, 'javascript item is same as original';
}

#-------------------------------------------------------------------------------
subtest "Javacsript with scope", {

  my Str $javascript = 'function(x){return x;}';
  my BSON::Document $scope .= new: (nn => 10, a1 => 2);
  my BSON::Javascript $js-scope .= new( :$javascript, :$scope);
  my BSON::Document $d1 .= new: (:$js-scope,);
  my Buf $b1 = $d1.encode;

  # prepare compare buffer and compare with encoded document
  my Buf $b2 =
    [~] Buf.new(0x0F),                              # BSON javascript with scope
       'js-scope'.encode, Buf.new(0x00),            # 'js-scope'
        Buf.new.write-int32(0, $javascript.chars + 1, LittleEndian),
          $javascript.encode, Buf.new(0x00),        # javascript code
          $scope.encode,                            # encoded scope
        Buf.new(0x00);                              # end of document
                                                    # prepend size to b2
  is-deeply Buf.new.write-int32(0, $b2.elems + 4, LittleEndian) ~ $b2, $b1,
            'check encoded javascript';


  my BSON::Document $d2 .= new($b1);
  is-deeply $d1<js-scope>, $d2<js-scope>,
      'scoped javascript is same as original';
}

#-------------------------------------------------------------------------------
subtest "Javacsript with scope, twice", {

  my Str $javascript = 'function(x){return x;}';
  my BSON::Document $scope .= new: (nn => 10, a1 => 2);
  my BSON::Javascript $js-scope1 .= new( :$javascript, :$scope);
  my BSON::Javascript $js-scope2 .= new( :$javascript, :$scope);

  my BSON::Document $d1 .= new: ( :jsc1($js-scope1), :jsc2($js-scope2));
  my Buf $b1 = $d1.encode;

  my BSON::Document $d2 .= new($b1);
  is-deeply $d1<jsc1>, $d2<jsc1>, 'jsc1 decoded doc is same as original';
  is-deeply $d1<jsc2>, $d2<jsc2>, 'jsc2 decoded doc is same as original';
}

#-------------------------------------------------------------------------------
# Cleanup
done-testing;

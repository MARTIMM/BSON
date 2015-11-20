use v6;
use BSON::EDCTools;

package BSON {

  class Javascript {

    has Str $.javascript;
    has $.scope;

    has Bool $.has-javascript = False;
    has Bool $.has-scope = False;

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( Str:D :$javascript, :$scope ) {

      # Store the attribute values. ? sets True if defined and filled.
      #
      $!javascript = $javascript;
      $!scope = $scope;

      $!has-javascript = ?$!javascript;
      $!has-scope = ?$!scope if $scope.^name ~~ 'BSON::Document';
    }

    #---------------------------------------------------------------------------
    #
    method encode-javascript ( Str $key-name, $bson-obj --> Buf ) {
      if $!has-javascript {
        my Buf $js = encode-string($!javascript);

        if $!has-scope {
          my Buf $doc = $bson-obj.encode-document($!scope);
          return [~] Buf.new(0x0F), encode-e-name($key-name),
                     encode-int32([+] $js.elems, $doc.elems, 4), $js, $doc;
        }

        else {
          return [~] Buf.new(0x0D), encode-e-name($key-name), $js;
        }
      }

      else {
        die X::BSON::ImProperUse.new( :operation('encode'),
                                      :type('javascript 0x0D/0x0F'),
                                      :emsg('cannot send empty code')
                                    );
      }
    }

    #---------------------------------------------------------------------------
    #
    method decode-javascript ( Array $a, $index is rw --> Pair ) {

      return decode-e-name( $a, $index) =>
        BSON::Javascript.new( :javascript(decode-string( $a, $index)));
    }
  }
}


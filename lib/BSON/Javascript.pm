use v6;

class BSON::Javascript {

  has Str $.javascript;
  has Hash $.scope;
  
  has Bool $.has_scope = False;
  
  submethod BUILD ( Str :$javascript, Hash :$scope) {
  
      # Store the attribute values. ? sets True if defined and filled.
      #
      $!javascript = ?$javascript ?? $javascript !! 'function() {}';
      $!scope = $scope;
      $!has_scope = ?$!scope;
  }
}

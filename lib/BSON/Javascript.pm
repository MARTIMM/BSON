use v6;

class BSON::Javascript {

  has Str $.javascript;
  
  submethod BUILD (:$javascript) {
  
      # Store the attribute values.
      #
      $!javascript = $javascript // '';
  }
}

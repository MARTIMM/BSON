use v6;

package BSON {

  class Document does Associative {

    has @!keys;
    has Hash $!data;

    #-----------------------------------------------------------------------------
    multi method AT-KEY ( Str $key --> Mu ) is rw {

      my $value;
      if ! ($!data{$key}:exists) {
        $!data{$key} = '';
        @!keys.push($key);
      }

      $value := $!data{$key};
    }

    #-----------------------------------------------------------------------------
    multi method EXISTS-KEY ( Str $key --> Bool ) {

      return $!data{$key}:exists;
    }

    #-----------------------------------------------------------------------------
    multi method DELETE-KEY ( Str $key --> Any ) {

      my $value;
      if $!data{$key}:exists {
        loop ( my $i = 0; $i < @!keys.elems; $i++ ) {
          if @!keys[$i] ~~ $key {
            @!keys.splice( $i, 1);
            $value = $!data{$key}:delete;
            last;
          }
        }
      }

      $value;
    }

    #-----------------------------------------------------------------------------
    multi method BIND-KEY ( Str $key, \new) {

      say "BIND-KEY $key {new}";

      $!data{$key} := new;
    }

    #-----------------------------------------------------------------------------
    multi method elems ( --> Int ) {

      @!keys.elems;
    }

    #-----------------------------------------------------------------------------
    multi method kv ( --> List ) {

      my @l;
      for @!keys -> $k {
        @l.push( $k, $!data{$k});
      }

      @l;
    }

    #-----------------------------------------------------------------------------
    multi method keys ( --> List ) {

      @!keys.list;
    }
  }
}


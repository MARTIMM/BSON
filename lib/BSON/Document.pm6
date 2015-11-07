use v6;

package BSON {

  class Document does Associative {

    has @!keys;
    has @!values;

    #-----------------------------------------------------------------------------
    multi method AT-KEY ( Str $key --> Mu ) is rw {

      my $value;
      loop ( my $i = 0; $i < @!keys.elems; $i++ ) {
        if @!keys[$i] ~~ $key {
          $value := @!values[$i];
          last;
        }
      }

      if $i == @!keys.elems {
        @!keys[$i] = $key;
        @!values[$i] = '';
        $value := @!values[$i];
      }

      $value;
    }

    #-----------------------------------------------------------------------------
    multi method EXISTS-KEY ( Str $key --> Bool ) {

      my Bool $v = False;
      loop ( my $i = 0; $i < @!keys.elems; $i++ ) {
        if @!keys[$i] ~~ $key {
          $v = True;
          last;
        }
      }

      $v;
    }

    #-----------------------------------------------------------------------------
    multi method DELETE-KEY ( Str $key --> Any ) {

      my $v = Nil;
      loop ( my $i = 0; $i < @!keys.elems; $i++ ) {
        if @!keys[$i] ~~ $key {
          @!keys.splice( $i, 1);
          $v = @!values.splice( $i, 1);
          last;
        }
      }
      
      $v;
    }

  #  multi method ASSIGN-KEY ( $key, $value --> )

    #-----------------------------------------------------------------------------
    multi method elems ( --> Int ) {

      @!keys.elems;
    }

    #-----------------------------------------------------------------------------
    multi method kv ( --> List ) {

      (@!keys Z @!values).flat.list;
    }

    #-----------------------------------------------------------------------------
    multi method keys ( --> List ) {

      @!keys.list;
    }
  }
}


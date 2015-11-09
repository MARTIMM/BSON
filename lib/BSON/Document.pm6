use v6;

package BSON {

  class Document does Associative does Positional {

    has Str @!keys;
    has Hash $!data .= new;

    has Buf $!encoded-document;
    has Buf @!encoded-entries;
    has Bool $!encoded;

    #---------------------------------------------------------------------------
    #
    method new ( *@ps ) {
      self.bless(:pairs(@ps));
    }

    submethod BUILD (:@pairs) {
      $!encoded = False;

      for @pairs -> $pair {
        self{$pair.key} = $pair.value;
      }
    }

    #---------------------------------------------------------------------------
    # Associative role methods
    #---------------------------------------------------------------------------
    multi method AT-KEY ( Str $key --> Any ) {

      $!data{$key}:exists ?? $!data{$key} !! Any;
    }

    #---------------------------------------------------------------------------
    multi method EXISTS-KEY ( Str $key --> Bool ) {

      return $!data{$key}:exists;
    }

    #---------------------------------------------------------------------------
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

    #---------------------------------------------------------------------------
    multi method ASSIGN-KEY ( $key, $new) {

      @!keys.push($key) unless $!data{$key}:exists;
      $!data{$key} = $new;
    }

    #---------------------------------------------------------------------------
    multi method BIND-KEY ( Str $key, \new ) {

      $!data{$key} := new;
    }

    #---------------------------------------------------------------------------
    # Positional role methods
    #---------------------------------------------------------------------------
    subset Index of Int where $_ >= 0;

    #---------------------------------------------------------------------------
    multi method elems ( --> Int ) {

      @!keys.elems;
    }

    #---------------------------------------------------------------------------
    multi method AT-POS ( Index $idx --> Any ) {

      $idx < @!keys.elems ?? $!data{@!keys[$idx]} !! Any;
    }

    #---------------------------------------------------------------------------
    multi method EXISTS-POS ( Index $idx --> Bool ) {

      $idx < @!keys.elems;
    }

    #---------------------------------------------------------------------------
    multi method DELETE-POS ( Index $idx --> Any ) {

      $idx < @!keys.elems ?? (self{@!keys[$idx]}:delete) !! Nil;
    }

    #---------------------------------------------------------------------------
    multi method ASSIGN-POS ( Index $idx, $new! ) {

      # If index is at a higher position then the last one then only
      # one place extended with a generated key na,e such as key21 on the
      # 21st location. Furthermore when a key like key21 has been used before
      # the array is not extended but the key location is used instead.
      #
      my $key = $idx >= @!keys.elems ?? 'key' ~ @!keys.elems !! @!keys[$idx];

      @!keys.push($key) unless $!data{$key}:exists;
      $!data{$key} = $new;
    }

    #---------------------------------------------------------------------------
    multi method BIND-POS ( Index $idx, \new ) {

      my $key = $idx >= @!keys.elems ?? 'key' ~ @!keys.elems !! @!keys[$idx];
      $!data{$key} := new;
    }

    #---------------------------------------------------------------------------
    # Must be defined because of Positional and Associative
    #---------------------------------------------------------------------------
    method of (  ) {
      Mu;
    }

    #---------------------------------------------------------------------------
    # And some extra methods
    #---------------------------------------------------------------------------
    multi method kv ( --> List ) {

      my @l;
      for @!keys -> $k {
        @l.push( $k, $!data{$k});
      }

      @l;
    }

    #---------------------------------------------------------------------------
    multi method keys ( --> List ) {

      @!keys.list;
    }

    #---------------------------------------------------------------------------
    multi method values ( --> List ) {

      $!data{@!keys[*]}.list;
    }
  }
}


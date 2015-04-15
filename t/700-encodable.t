use v6;
use Test;
use BSON::Encodable;

#-------------------------------------------------------------------------------
# Forgotten code test
#
if 1 {
  class MyThing0 does BSON::Encodable {

    multi method new( Str :$key_name, :$key_data --> MyThing0 ) {
        return self.bless( :bson_code(Int), :$key_name, :$key_data);
    }

    method encode( --> Buf ) { }
    method decode( List $b ) { }
  }

  my MyThing0 $m0;
#  say "m0: {$m0.^name}";

  CATCH {
    when X::BSON::Encodable {
      my $emsg = $_.emsg;
      $emsg ~~ s:g/\n+//;

      ok $_.type ~~ m/MyThing1/, 'Thrown object';
      is $emsg, "Code 511 out of bounds, must be positive 8 bit int", $emsg;
    }
  }
}

#-------------------------------------------------------------------------------
# Code too large test
#
if 1 {
  class MyThing1 does BSON::Encodable {

    multi method new( Str :$key_name, :$key_data --> MyThing1 ) {
        return self.bless( :bson_code(0x01FF), :$key_name, :$key_data);
    }

    method encode( --> Buf ) { }
    method decode( List $b ) { }
  }

  my MyThing1 $m1 .= new( :key_name('t'), :key_data(10));
#  say "m1: {$m1.^name}";

  CATCH {
    when X::BSON::Encodable {
      my $emsg = $_.emsg;
      $emsg ~~ s:g/\n+//;

      ok $_.type ~~ m/MyThing1/, 'Thrown object';
      is $emsg, "Code 511 out of bounds, must be positive 8 bit int", $emsg;
    }
  }
}

#-------------------------------------------------------------------------------
# Role to encode to and/or decode from a BSON representation from a Thing.
# 
class MyThing2 does BSON::Encodable {

  multi method new( Str :$key_name, :$key_data --> MyThing2 ) {

      return self.bless( :bson_code(0x01), :$key_name, :$key_data);
  }

  method encode( --> Buf ) {
      return [~] self!encode_code,
                 self!encode_key,
                 self!enc_int32($!key_data);
  }

  # Decode a binary buffer to internal data.
  #
  method decode( List $b ) {
      self!decode_code($b);
      self!decode_key($b);
      $!key_data = self!dec_int32($b.list);
  }
}


my MyThing2 $m .= new( :bson_code(0x01), :key_name('test'), :key_data(10));


isa_ok $m, 'MyThing2', 'Is a thing';
#ok $m.^does(BSON::Encodable), 'Does BSON::Encodable role';

#`{{}}
my Buf $bdata = $m.encode();
is_deeply $bdata,
          Buf.new( 0x01,                                # BSON code
                   0x74, 0x65, 0x73, 0x74, 0x00,        # 'test' + 0
                   0x0A, 0x00 xx 3,                     # 32 bit integer
                 ),
          'encoding 10';

my MyThing2 $m2 .= new;
$m2.decode($bdata.list);
is $m2.key_data, $m.key_data, 'Compare item after encode decode';


#-------------------------------------------------------------------------------
# Cleanup
#
done();
exit(0);

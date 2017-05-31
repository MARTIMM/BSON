#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define DECNUMDIGITS 34            // work with up to 34 digits
#include "decNumber.h"             // base number library
#include "decimal128.h"

#define BYTE_TO_BINARY_PATTERN "%c%c%c%c%c%c%c%c"
#define byte unsigned char

//-----------------------------------------------------------------------------
void printByteBin( byte b ) {
  printf( BYTE_TO_BINARY_PATTERN,
    (b & 0x80 ? '1' : '0'),    (b & 0x40 ? '1' : '0'),
    (b & 0x20 ? '1' : '0'),    (b & 0x10 ? '1' : '0'),
    (b & 0x08 ? '1' : '0'),    (b & 0x04 ? '1' : '0'),
    (b & 0x02 ? '1' : '0'),    (b & 0x01 ? '1' : '0')
  );
  printf(" ");
}

//-----------------------------------------------------------------------------
void showD128Pattern( char *x ) {

  decContext set;
  decContextDefault( &set, DEC_INIT_BASE); // initialize
  set.traps = 0;
  set.digits=DECNUMDIGITS;


  union bits {
    decimal128 d128;
    byte b128[16];
  } v;

  decNumber dn;
  decNumberFromString( &dn, x, &set);
  decimal128FromNumber( &(v.d128), &dn, &set);


  printf( "N = %s\n  ", x);
  for( int i=0; i<16; i++) {
    printf( " 0x%02x,", v.b128[i]);
    if( !((i+1) % 8) ) { printf("\n  "); }
  }
  printf( "\n");

/*
  for( int i=0; i<16; i++) {
    printByteBin(v.b128[i]);
    if( !((i+1) % 8) ) { printf("\n"); }
  }

  printf( "\n");
*/
}

//-----------------------------------------------------------------------------
int main( int argc, char *args[]) {

  for( int i = 1; i < argc; i++) {
    showD128Pattern(args[i]);
  }
}

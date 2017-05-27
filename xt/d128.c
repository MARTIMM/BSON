// gcc -o d128 d128.c

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>

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
void showD128Pattern( double x ) {

  struct bits {
    _Decimal128 d128;
    byte b128[16];
  } v;

  v.d128 = x;
  printf( "N = %f: ", x);
  for( int i=0; i<16; i++) {
    printf( " %02x", v.b128[i]);
  }
  printf( "\n");

  for( int i=0; i<16; i++) {
    printByteBin(v.b128[i]);
    if( !((i+1) % 8) ) { printf("\n"); }
  }

  printf( "\n");
}

//-----------------------------------------------------------------------------
int main( int argc, char *args[]) {

  for( int i = 1; i < argc; i++) {
printf( "A: %s, %f\n", args[i], atof(args[i]));
    showD128Pattern(atof(args[i]));
  }
}

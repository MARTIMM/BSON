# compiler
CC=gcc

# compiler options
CFLAGS=-Wall -O3 -IdecNumber -Ldfpal -lDFPAL

# targets
d128-v1: d128-v1.c decNumber/decimal128.c decNumber/decNumber.c decNumber/decContext.c
	$(CC) $(CFLAGS) -o $@ $^

d128-v2: d128-v2.c
	$(CC) $(CFLAGS) -lgcc_s -o $@ $^

e1: decNumber/example1.c decNumber/decNumber.c decNumber/decContext.c
	$(CC) $(CFLAGS) -o $@ $^

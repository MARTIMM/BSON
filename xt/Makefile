# compiler
CC=gcc

# compiler options
CFLAGS=-Wall -O3 -IdecNumber

# targets
d128-v1: d128-v1.c decNumber/decNumber.c decNumber/decContext.c
	$(CC) $(CFLAGS) -o $@ $^

d128-v2: d128-v2.c
	$(CC) $(CFLAGS) -o $@ $^

e1: decNumber/example1.c decNumber/decNumber.c decNumber/decContext.c
	$(CC) $(CFLAGS) -o $@ $^

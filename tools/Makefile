CC=gcc
CFLAGS=-Wall

.PHONY: all

all: $O/build

$O/build: build.c
	${CC} ${CFLAGS} build.c -o $@

$O/%.o: %.c
	${CC} ${CFLAGS} -m64 -c $^ -o $@

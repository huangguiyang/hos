IMG=floppy.img
CC=gcc
LD=ld
CFLAGS=-Wall

.PHONY: all

all: $(IMG)

$(IMG): build ../boot/bootsect ../boot/boot ../kern/kernel
	./build ../boot/bootsect ../boot/boot ../boot/kernel > $@

../boot/bootsect:
	cd ../boot && make bootsect

../boot/boot:
	cd ../boot && make boot

../kern/kernel:
	cd ../kern && make kernel

%.o: %.c
	${CC} ${CFLAGS} -m64 -c $^ -o $@

build: build.c
	${CC} ${CFLAGS} build.c -o build

clean::
	@rm -f *.o $(IMG) build

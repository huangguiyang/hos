CC=gcc
LD=ld
CFLAGS=-Wall
O=$(abspath build)

.PHONY: all clean createdir

all: createdir $O/floppy.img

createdir:
	mkdir -p $O

$O/floppy.img: $O/build $O/bootsect $O/loader $O/kern64
	$O/build $O/bootsect $O/loader $O/kern64 > $@

$O/bootsect $O/loader: boot/*.s
	O=$O make -C boot

$O/kern64: kern/*.s kern/*.c kern/*.h
	O=$O make -C kern

$O/build: tools/*.c
	O=$O make -C tools

clean:
	@rm -rf $O

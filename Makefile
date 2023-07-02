CC=gcc
LD=ld
CFLAGS=-Wall
O=$(abspath build)
IMG=floppy.img

.PHONY: all clean createdir

all: createdir ${IMG}

createdir:
	mkdir -p $O

${IMG}: $O/build $O/bootsect $O/loader $O/kern64
	$O/build $O/bootsect $O/loader $O/kern64 > $@

$O/bootsect $O/loader: boot/*.s
	O=$O make -C boot

$O/kern64: kern/*.s kern/*.c kern/*.h
	O=$O make -C kern

$O/build: tools/*.c
	O=$O make -C tools

clean:
	@rm -rf $O ${IMG}

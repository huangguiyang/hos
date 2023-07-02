AS=as
LD=ld
LDFLAGS=-nostdlib
OBFLAGS=-O binary -j .text -j .data -j .bss -j .rodata

.PHONY: all

all: $O/bootsect $O/loader

$O/bootsect: $O/bootsect.o
	${LD} ${LDFLAGS} -m elf_i386 -Ttext 0x7c00 $^ -o $@
	objcopy ${OBFLAGS} $@

$O/bootsect.o: bootsect.s
	${AS} --32 $^ -o $@

$O/loader: $O/loader.o
	${LD} ${LDFLAGS} -m elf_i386 -Ttext 0xF000 $^ -o $@
	objcopy ${OBFLAGS} $@

$O/loader.o: loader.s
	${AS} --32 $^ -o $@

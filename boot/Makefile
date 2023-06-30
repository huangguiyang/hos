AS=as
LD=ld
LDFLAGS=-nostdlib
OBFLAGS=-O binary -j .text -j .data -j .bss -j .rodata

.PHONY: all

all: $O/bootsect $O/boot

$O/bootsect: $O/bootsect.o
	${LD} -m elf_i386 -Ttext 0x7c00 $^ -o $@
	objcopy ${OBFLAGS} $@

$O/bootsect.o: bootsect.s
	${AS} --32 $^ -o $@

$O/boot: $O/boot.o
	${LD} ${LDFLAGS} -m elf_i386 -Ttext 0 $^ -o $@
	objcopy ${OBFLAGS} $@

$O/boot.o: boot.s
	${AS} --32 $^ -o $@

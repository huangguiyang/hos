
AS=as
LD=ld
LDFLAGS=-nostdlib
OBFLAGS=-O binary -j .text -j .data -j .bss -j .rodata

.PHONY: all

all: bootsect boot

bootsect: bootsect.o
	${LD} -m elf_i386 -Ttext 0 $^ -o $@
	objcopy ${OBFLAGS} $@

bootsect.o: bootsect.s
	${AS} --32 $^ -o $@

boot: boot.o
	${LD} ${LDFLAGS} -m elf_i386 -Ttext 0 $^ -o $@
	objcopy ${OBFLAGS} $@

boot.o: boot.s
	${AS} --32 $^ -o $@

clean::
	@rm -f bootsect boot *.o


A=a
B=b
C=c
T=floppy.img
AOFF=0
BOFF=0
COFF=0
OBJS=$C.o k.o
# no-builtin-printf: 不要把printf调用优化成puts
# no-asynchronous-unwind-tables: 不要 .eh_frame section
# no-stack-protector: GCC11 undefined __stack_chk_fail
CFLAGS=-Wall -m32 \
		-nostdlib \
		-nostdinc \
		-fno-builtin \
		-fno-pic \
		-fno-pie \
		-fno-exceptions \
		-fno-unwind-tables \
		-fno-builtin-printf \
		-fno-asynchronous-unwind-tables \
		-fno-stack-protector
LDFLAGS=-nostdlib -m elf_i386
OBFLAGS=-O binary -R .comment -R .note -R .note.gnu.property

$T: $A.bin $B.bin $C.bin build
	./build $A.bin $B.bin $C.bin > $@

$A.bin: $A.s
	as --32 $A.s -o $A.o
	ld -m elf_i386 -Ttext ${AOFF} $A.o -o $@
	objcopy ${OBFLAGS} $@

$B.bin: $B.s
	as --32 $B.s -o $B.o
	ld -m elf_i386 -Ttext ${BOFF} $B.o -o $@
	objcopy ${OBFLAGS} $@

$C.o: $C.s
	as --32 $C.s -o $C.o

%.o: %.c
	gcc ${CFLAGS} -c $< -o $@

$C.bin: ${OBJS}
	ld ${LDFLAGS} -Ttext ${COFF} ${OBJS} -o $@
	cp $@ $C.orig.bin
	objcopy ${OBFLAGS} $@

build: build.c
	gcc -Wall build.c -o build

clean::
	@rm -f *.bin *.o $T build

%.c: kern.h

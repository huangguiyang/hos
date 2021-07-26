
A=a
B=b
C=c
T=Image
AOFF=0
BOFF=0
COFF=0
OBJS=$C.o k.o
# no-builtin-printf: 不要把printf调用优化成puts
# no-asynchronous-unwind-tables: 不要 .eh_frame section
CFLAGS=-Wall -m32 \
		-nostdlib \
		-nostdinc \
		-fno-builtin \
		-fno-pic \
		-fno-pie \
		-fno-exceptions \
		-fno-unwind-tables \
		-fno-builtin-printf \
		-fno-asynchronous-unwind-tables
LDFLAGS=-nostdlib -m elf_i386

$T: $A.bin $B.bin $C.bin build
	./build $A.bin $B.bin $C.bin > $@

$A.bin: $A.s
	as --32 $A.s -o $A.o
	ld -m elf_i386 -Ttext ${AOFF} --oformat binary $A.o -o $@

$B.bin: $B.s
	as --32 $B.s -o $B.o
	ld -m elf_i386 -Ttext ${BOFF} --oformat binary $B.o -o $@

$C.o: $C.s
	as --32 $C.s -o $C.o

%.o: %.c
	gcc ${CFLAGS} -c $< -o $@

$C.bin: ${OBJS}
	ld ${LDFLAGS} -Ttext ${COFF} ${OBJS} -o $@
	cp $@ $C.orig.bin
	objcopy -O binary -R .comment -R .note $@

build: build.c
	gcc -Wall build.c -o build

clean::
	@rm -f *.bin *.o $T build

%.c: kern.h


A=a
B=b
C=c
T=floppy.img
AOFF=0
BOFF=0
COFF=0xC000
OBJS=$C.o main.o printf.o
## no-builtin-printf: 不要把printf调用优化成puts
CFLAGS=-Wall -nostdlib -nostdinc -fno-pic -fno-pie \
		-fno-exceptions -fno-unwind-tables -fno-builtin-printf
LDFLAGS=-nostdlib

$T: $A.bin $B.bin $C.bin build
	./build $A.bin $B.bin $C.bin > $@

$A.bin: $A.s
	as $A.s -o $A.o
	ld -Ttext ${AOFF} --oformat binary $A.o -o $@

$B.bin: $B.s
	as $B.s -o $B.o
	ld -Ttext ${BOFF} --oformat binary $B.o -o $@

$C.o: $C.s
	as $C.s -o $C.o

%.o: %.c
	gcc ${CFLAGS} -c $< -o $@

$C.bin: ${OBJS}
	ld ${LDFLAGS} -Ttext ${COFF} ${OBJS} -o $@
#	objcopy --remove-section .comment $@
#	objcopy --remove-section .eh_frame $@
#	strip $@

build: build.c
	gcc -Wall build.c -o build

clean::
	@rm -f *.bin *.o $T build

%.c: kern.h

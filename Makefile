T=floppy.img
# no-builtin-printf: 不要把printf调用优化成puts
# 内置的printf相关的通通不需要，但一些内置方法是需要的，例如 __builtin_va_arg
# 所以不能禁掉所有builtins
# no-builtin-vsnprintf
# no-builtin-puts
# no-builtin-putc
# no-asynchronous-unwind-tables: 不要 .eh_frame section
# no-stack-protector: GCC11 undefined __stack_chk_fail
CC=gcc
AS=as
LD=ld
CFLAGS=-Wall \
	-nostdlib \
	-nostdinc \
	-fno-pic \
	-fno-pie \
	-fno-exceptions \
	-fno-unwind-tables \
	-fno-builtin-printf \
	-fno-builtin-vsnprintf \
	-fno-builtin-puts \
	-fno-builtin-putc \
	-fno-asynchronous-unwind-tables \
	-fno-stack-protector
LDFLAGS=-nostdlib
OBFLAGS=-O binary -j .text -j .data -j .bss -j .rodata
KERN_OBJS=start64.o main.o printf.o missing.o apic.o mp.o

$T: build bootsect boot kern64
	./build bootsect boot kern64 > $@

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

start64.o: start64.s
	${AS} --64 $^ -o $@

%.o: %.c
	${CC} ${CFLAGS} -m64 -c $^ -o $@

kern64: ${KERN_OBJS}
	${LD} ${LDFLAGS} -m elf_x86_64 -Ttext 0x10000 $^ -o $@
	objcopy ${OBFLAGS} $@

build: build.c
	${CC} -Wall build.c -o build

clean::
	@rm -f bootsect boot kern64 *.o $T build

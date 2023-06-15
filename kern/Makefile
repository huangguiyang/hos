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
KERN_OBJS=start16.o start64.o main.o printf.o

.PHONY: all

all: kernel

kernel: ${KERN_OBJS}
	${LD} ${LDFLAGS} -m elf_x86_64 -Ttext 0x10000 $^ -o $@
	objcopy ${OBFLAGS} $@

start16.o: start16.s
	${AS} --32 $^ -o $@

start64.o: start64.s
	${AS} --64 $^ -o $@

%.o: %.c
	${CC} ${CFLAGS} -m64 -c $^ -o $@

clean::
	@rm -f kern64 *.o

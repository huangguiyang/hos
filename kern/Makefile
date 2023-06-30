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
KERN_OBJS=$O/start64.o $O/main.o $O/printf.o

.PHONY: all

all: $O/kern64 $O/kern16

$O/kern64: ${KERN_OBJS}
	${LD} ${LDFLAGS} -m elf_x86_64 -Ttext 0x10000 $^ -o $@
	objcopy ${OBFLAGS} $@

$O/start64.o: start64.s
	${AS} --64 $^ -o $@

$O/kern16: $O/start16.o
	${LD} ${LDFLAGS} -m elf_i386 -Ttext 0x1000 $^ -o $@
	objcopy ${OBFLAGS} $@

$O/start16.o: start16.s
	${AS} --32 $^ -o $@

$O/%.o: %.c
	${CC} ${CFLAGS} -m64 -c $^ -o $@

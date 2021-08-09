T=floppy.img
# no-builtin-printf: 不要把printf调用优化成puts
# 内置的printf相关的通通不需要，但一些内置方法是需要的
# 例如 __builtin_va_arg
# no-builtin-vsnprintf
# no-builtin-puts
# no-builtin-putc
# no-asynchronous-unwind-tables: 不要 .eh_frame section
# no-stack-protector: GCC11 undefined __stack_chk_fail
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
OBFLAGS=-O binary -R .comment -R .note -R .note.gnu.property

$T: build bootsect boot kern64
	./build bootsect boot kern64 > $@

bootsect: bootsect.o
	ld -m elf_i386 -Ttext 0 $^ -o $@
	objcopy ${OBFLAGS} $@

bootsect.o: bootsect.s
	as --32 $^ -o $@

boot: boot.o
	ld ${LDFLAGS} -m elf_i386 -Ttext 0 $^ -o $@
	objcopy ${OBFLAGS} $@

boot.o: boot.s
	as --32 $^ -o $@

start64.o: start64.s
	as --64 $^ -o $@

%.o: %.c
	gcc ${CFLAGS} -m64 -c $^ -o $@

kern64: start64.o main.o printf.o missing.o
	ld ${LDFLAGS} -m elf_x86_64 -Ttext 0x10000 $^ -o $@
	objcopy ${OBFLAGS} $@

build: build.c
	gcc -Wall build.c -o build

clean::
	@rm -f bootsect boot kern64 *.o $T build

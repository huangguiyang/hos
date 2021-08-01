

T=floppy.img
OBJS=kern.o main.o
# no-builtin-printf: 不要把printf调用优化成puts
# no-asynchronous-unwind-tables: 不要 .eh_frame section
# no-stack-protector: GCC11 undefined __stack_chk_fail
CFLAGS=-Wall -m64 \
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
LDFLAGS=-nostdlib -m elf_x86_64
OBFLAGS=-O binary -R .comment -R .note -R .note.gnu.property

$T: boot setup16 setup32 setup64 kern64 build
	./build boot setup16 setup32 setup64 kern64 > $@

boot: boot.o
	ld -m elf_i386 -Ttext 0 $< -o $@
	objcopy ${OBFLAGS} $@

boot.o: boot.s
	as --32 $< -o $@

setup16: setup16.o
	ld -m elf_i386 -Ttext 0 $< -o $@
	objcopy ${OBFLAGS} $@

setup16.o: setup16.s
	as --32 $< -o $@

setup32: setup32.o
	ld -m elf_i386 -Ttext 0 $< -o $@
	objcopy ${OBFLAGS} $@

setup32.o: setup32.s
	as --32 $< -o $@

setup64: setup64.o
	ld -m elf_x86_64 -Ttext 0 $< -o $@
	objcopy ${OBFLAGS} $@

setup64.o: setup64.s
	as --64 $< -o $@

kern.o: kern.s
	as --64 $< -o $@

%.o: %.c
	gcc ${CFLAGS} -c $< -o $@

kern64: ${OBJS}
	ld ${LDFLAGS} -Ttext 0 $< -o $@
	objcopy ${OBFLAGS} $@

build: build.c
	gcc -Wall build.c -o build

clean::
	@rm -f boot setup16 setup32 setup64 kern64 *.o $T build

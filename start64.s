# loaded at 0x10000 (64K)

.code64

.set STACK_TOP, 0x9FFF0     # about 640K

.section .text
.globl _start, hlt, sti, cpuid
.globl inb, inw, indw, outb, outw, outdw
_start:
    movl $0x28, %eax            # 数据段选择符
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs

    lidtq idt_desc
    lgdtq gdt_desc

    movl $0x10, %eax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov %ax, %ss
    lss stack_top, %esp

    push $hlt
    call main
hlt:
    hlt

sti:
    sti
    ret

    # inb(int port, int *byte);
inb:
    mov %rdi, %rdx              # port
    inb %dx, %al                # read into AL
    movzbl %al, %eax
    movl %eax, (%rsi)
    ret

inw:
    mov %rdi, %rdx              # port
    inw %dx, %ax                # read into AX
    movzwl %ax, %eax
    movl %eax, (%rsi)
    ret

indw:
    mov %rdi, %rdx              # port
    inl %dx, %eax               # read into EAX
    movl %eax, (%rsi)
    ret

    # outb(int port, int byte);
outb:
    mov %rdi, %rdx              # port
    mov %rsi, %rax
    outb %al, %dx               # out to DX
    ret

outw:
    mov %rdi, %rdx              # port
    mov %rsi, %rax
    outw %ax, %dx               # out to DX
    ret

outdw:
    mov %rdi, %rdx              # port
    mov %rsi, %rax
    outl %eax, %dx              # out to DX
    ret

    # void cpuid(struct cpuinfo *);
cpuid:
    movl (%rdi), %eax
    movl 0x4(%rdi), %ebx
    movl 0x8(%rdi), %ecx
    movl 0xc(%rdi), %edx
    cpuid
    movl %eax, (%rdi)
    movl %ebx, 0x4(%rdi)
    movl %ecx, 0x8(%rdi)
    movl %edx, 0xc(%rdi)
    ret

.section .data

stack_top:
    .long STACK_TOP
    .word 0x10

.align 8
gdt:
    .quad 0                     # 第一个必须为空

    # 64位模式下，段限长、段基址字段没用了，随便填写

    .quad 0x00AF9A000000FFFF    # 代码段 D/B=0,L=1
    .quad 0x00CF92000000FFFF    # 数据段 D/B=1,L=0

.word 0
gdt_desc:
    .word 3*8-1                 # 限长
    .quad gdt                   # gdt地址

.word 0
idt_desc:
    .word 0
    .quad 0

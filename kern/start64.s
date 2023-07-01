# loaded at 0x1000:0x0000 (64K)

.code64

.set STACK_TOP, 0x9AFF0     # about 620K
.set STACK_TOP1, 0x9FFF0     # about 640K

.section .text
.globl _start
.globl hlt, sti, cpuid, pause
.globl inb, inw, indw, outb, outw, outdw
.globl rdmsr, wrmsr, set_cr3
_start:
    movl $0x20, %eax            # 数据段选择符 (index=4)
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs

    lidtq idt_desc
    lgdtq gdt_desc

     # 由于加载了新的 GDT，所以重新设置下段寄存器

    movl $0x10, %eax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov %ax, %ss

    # 不同核心需要使用不同的堆栈
    # 判断是否BSP
    movl $0x1b, %ecx
    rdmsr
    shrl $8, %eax
    andl $1, %eax
    cmp $0, %eax
    je ap_init
    
    lss stack_top, %esp
    call main
    hlt

ap_init:
    lss stack_top1, %esp
    call ap_main
    hlt

hlt:
    hlt
    ret

pause:
    pause
    ret

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

    # MSR指令说明：
    # RDMSR: 读取ECX指定的MSR到EDX:EAX
    # WRMSR: 将EDX:EAX写入ECX指定的MSR

    # addr=>edi, low=>rsi, high=>rdx

    # void rdmsr(int addr, int *low, int *high);
rdmsr:
    mov %rdx, %r8           # save high
    movl %edi, %ecx
    rdmsr
    cmp $0, %rsi
    je rdmsr_high
    movl %eax, (%rsi)
rdmsr_high:
    cmp $0, %r8
    je rdmsr_ret 
    movl %edx, (%r8)
rdmsr_ret:
    ret

    # void wrmsr(int addr, int low, int high);
wrmsr:
    movl %edi, %ecx
    movl %esi, %eax          # low (high already in edx)
    movl $0xFFFFFFFF, %edx
    wrmsr
    ret

    # void set_cr3(void *addr);
set_cr3:
    mov %rdi, %cr3
    ret

.section .data

stack_top:
    .long STACK_TOP
    .word 0x10

stack_top1:
    .long STACK_TOP1
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

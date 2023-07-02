# loaded at 0x10000

.include "../boot/defines.s"

.code64

.section .text
.globl _start
.globl halt, sti, cli, cpuid, pause
.globl inb, inw, indw, outb, outw, outdw
.globl rdmsr, wrmsr
.globl sync_lock_test_and_set, sync_lock_release
_start:
    movl $0x20, %eax            # 数据段选择符 (index=4)
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %ss
    mov %ax, %fs
    mov %ax, %gs

    lidtq idt_desc
    lgdtq gdt_desc

    # 由于加载了新的 GDT，所以重新设置下段寄存器

    movl $0x10, %eax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %ss
    mov %ax, %fs
    mov %ax, %gs

    # 不同核心需要使用不同的堆栈
    # 判断是否BSP
    movl $0x1b, %ecx
    rdmsr
    shrl $8, %eax
    andl $1, %eax
    cmp $0, %eax
    je ap_init
    
    # 每个 CPU 分配独立的 4K 栈

bsp_init:
    mov $0x1000, %rsp
    xadd %rsp, (next_sp)
    call main
bsp_die:
    hlt
    jmp bsp_die

ap_init:
    mov $0x1000, %rsp
    lock xadd %rsp, (next_sp)       # AP 是并行进入的，需要加锁
    call ap_main
ap_die:
    hlt
    jmp ap_die

    # void halt();
halt:
    hlt
    ret

    # void pause();
pause:
    pause
    ret

    # void sti();
sti:
    sti
    ret

    # void cli();
cli:
    cli
    ret

    # void inb(int port, int *byte);
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

    # void outb(int port, int byte);
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

    # int sync_lock_test_and_set(void *p);
    # 加锁设置 *p = 1 并返回其原值
sync_lock_test_and_set:
    movl $1, %eax
    lock xchgb %al, (%rdi)
    ret

    # void sync_lock_release(void *p);
sync_lock_release:
    xorl %eax, %eax
    lock xchgb %al, (%rdi)
    mfence
    ret

.section .data

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

next_sp:
    .quad KERNEL_STACK_BASE

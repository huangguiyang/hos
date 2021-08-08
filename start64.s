# loaded at 0x10000 (64K)

.code64

.set STACK_TOP, 0x9FFF0     # about 640K

.section .text
.globl _start, set_cursor, read_cursor, hlt, sti
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

# https://bochs.sourceforge.io/techspec/PORTS.LST

    # 彩色显示器
    # 内存范围：0xB8000 - 0XBFFFF，共32KB
    # 支持8页，每页 80列 x 25行
    # 每个字符255个属性，占两个字节，因此一页内容4000字节
    #
    # 读取光标位置
    # 索引寄存器：0x03D4
    #           0x0E - 光标位置高8位
    #           0x0F - 光标位置低8位
    # 数据寄存器：0x03D5

    # int read_cursor(void);
    # 读取光标位置
read_cursor:
    push %rcx
    push %rdx
    
    xor %ecx, %ecx          # 主要是为了清空高16位
    movb $0x0e, %al         # 指令必须使用AL
    movw $0x03d4, %dx       # 指令必须使用DX
    outb %al, %dx
    movw $0x03d5, %dx
    inb %dx, %al            # 读取高位
    movb %al, %ch

    movb $0x0f, %al
    movw $0x03d4, %dx
    outb %al, %dx
    movw $0x03d5, %dx
    inb %dx, %al            # 读取低位
    movb %al, %cl

    mov %ecx, %eax
    pop %rdx
    pop %rcx
    ret

    # void set_cursor(int position);
    # 设置光标位置
set_cursor:
    push %rbp
    mov %rsp, %rbp
    push %rax
    push %rbx
    push %rcx
    push %rdx

    mov 0x8(%ebp), %ebx     # position

    movb $0x0e, %al         # 指令必须使用AL
    movw $0x03d4, %dx       # 指令必须使用DX
    outb %al, %dx
    movw $0x03d5, %dx
    movb %bh, %al
    outb %al, %dx           # 写入高位

    movb $0x0f, %al
    movw $0x03d4, %dx
    outb %al, %dx
    movw $0x03d5, %dx
    movb %bl, %al
    outb %al, %dx            # 写入低位

    pop %rdx
    pop %rcx
    pop %rbx
    pop %rax
    leave
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

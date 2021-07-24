# 32位保护模式

.code32

.section .text
.globl _start, sti
_start:
    movw $0x10, %ax         # 数据段选择子
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %fs
    movw %ax, %gs
    lss stack_top, %esp

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

    call read_cursor

    movl $0xb8000, %ebx
    sal $0x1, %ecx
    addl %ecx, %ebx
    movb $0x43, %al
    movb $0x02, %ah
    movw %ax, (%ebx)

    #call main
    #hlt
loop:
    jmp loop

    # 读取光标位置到ECX
read_cursor:
    xor %ecx, %ecx
    
    movb $0x0e, %al         # 指令必须使用AL
    movw $0x03d4, %dx       # 指令必须使用DX
    outb %al, %dx
    movw $0x03d5, %dx
    inb %dx, %al
    movb %al, %ch

    movb $0x0f, %al
    movw $0x03d4, %dx
    outb %al, %dx
    movw $0x03d5, %dx
    inb %dx, %al
    movb %al, %cl
    ret

sti:
    sti
    ret

# 16-bits selector
# 32-bits offset
stack_top:
    .long 0x9B000           # 620K
    .word 0x10

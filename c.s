# 32位保护模式
# 系统内存分布：
# 0 ~ 512K: kernel
# 600K: (0x96000): setup        重新加载GDT,IDT后即可废弃
# 620K: (0x9B000): stack top
# 620K ~ 640K: saved parameters

.code32

.set STACK_TOP, 0x9B000         # 620K

.section .text
.globl _start, sti, gdt, idt, page_dir, page_table, read_cursor, set_cursor
_start:
    mov $0x10, %ax         # 数据段选择子
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    lss stack_top, %esp

    # 重新加载GDT,IDT
    lgdt gdt_desc
    call setup_idt

    mov $0x10, %ax         # 数据段选择子
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
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

    call main
    hlt

setup_idt:
    lea ignore_idt, %edx
    mov $0x00080000, %eax
    movw %dx, %ax
    movw $0x8e00, %dx
    lea idt, %edi
    mov $256, %ecx
rp_sidt:
    mov %eax, (%edi)
    mov %edx, 4(%edi)
    add $8, %edi
    dec %ecx
    jne rp_sidt
    lidt idt_desc
    ret

.align 4
ignore_idt:
    push %eax
    push %ecx
    push %edx
    push %ds
    push %es
    push %fs

    # do nothing

    pop %fs
    pop %es
    pop %ds
    pop %edx
    pop %ecx
    pop %eax
    iret


    # int read_cursor(void);
    # 读取光标位置
read_cursor:
    push %ecx
    push %edx
    
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
    pop %edx
    pop %ecx
    ret

    # void set_cursor(int position);
    # 设置光标位置
set_cursor:
    push %ebp
    mov %esp, %ebp
    push %eax
    push %ebx
    push %ecx
    push %edx

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

    pop %edx
    pop %ecx
    pop %ebx
    pop %eax
    leave
    ret

    # void sti(void);
    # 开中断
sti:
    sti
    ret

.align 4
stack_top:
    .long STACK_TOP             # 32-bits offset
    .word 0x10                  # 16-bits selector

.align 8
# 全局描述符表
gdt:
    .word 0,0,0,0       # 第一个必须为空
    
    # 0-4GB的代码段
    .word 0xFFFF        # limit
    .word 0x0000        # 基址
    .word 0x9A00        # 代码段，rx权限
    .word 0x00C0        # 粒度-4K，32位操作数

    # 0-4GB的数据段
    .word 0xFFFF        # limit
    .word 0x0000        # 基址
    .word 0x9200        # 数据段，rw权限
    .word 0x00C0        # 粒度-4K，32位操作数

    .fill 3,8,0         # 预留

# GDT的描述符，用来加载到GDTR
gdt_desc:
    .word 0x002f        # 限长：6个*8字节/个=48字节 (0x30-1)
    .long gdt           # gdt地址

.align 8
idt:
    .fill 256,8,0

idt_desc:
    .word 256*8-1
    .long idt

.align 8
page_dir:
page_table:

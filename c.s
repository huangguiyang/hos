# 32位保护模式
# 系统内存分布：
# 0 ~ 512K: kernel
# 600K: (0x96000): setup        重新加载GDT,IDT后即可废弃
# 620K: (0x9B000): stack top
# 620K ~ 640K: saved parameters

.code32

.set STACK_TOP, 0x9B000         # 620K

.section .text
.globl _start, sti, hlt, gdt, idt, read_cursor, set_cursor
.globl page_fault_handler, divide_error_handler
.globl page_dir
_start:
    mov $0x10, %eax         # 数据段选择子
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    lss stack_top, %esp

    # 重新加载GDT,IDT
    call setup_idt
    lgdt gdt_desc

    mov $0x10, %eax         # 数据段选择子
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    lss stack_top, %esp
    
    # 开启分页后需要一次跳转（改变了CR0寄存器），前面已压栈main函数
    # main函数设计成不会返回，若返回则停机
    #push $main              # 压栈
    #call setup_paging       # 开启分页功能
    call main
die:
    hlt

    # 开启分页（可选）
setup_paging:
    # 初始化页目录
    movl $page_table1 + 7, page_dir      # A=0,PCD=0,PWT=0,U/S=1,R/W=1,P=1
    movl $page_table2 + 7, page_dir+4
    movl $page_table3 + 7, page_dir+8
    movl $page_table4 + 7, page_dir+12

    # 初始化页表 [0-255] 即 0-1MB 内存页
    mov $page_dir, %ebx
    mov (%ebx), %ebx
    and 0xfffff000, %ebx        # eax = 第一个页表地址
    mov $256, %ecx
    xor %eax, %eax
    add $3, %eax                # U/S=0,R/W=1,P=1
rp_pte:
    mov %eax, (%ebx)
    add $0x1000, %eax           # 加4K
    add $4, %ebx
    dec %ecx
    jne rp_pte

    # 修改CR3和CR0寄存器，开启分页
    # CR3指向页目录，CR0设置PG位
    # 由于页目录4K对齐，直接mov到CR3即可
    mov $page_dir, %eax
    mov %eax, %cr3              # PCD=0,PWT=0
    or $0x80000000, %eax        # 最高位是PG (Paging)
    mov %eax, %cr0              # PG=1
    ret                         # 由于前面压栈main，这里会跳转到main执行
    hlt

    # 中断描述符的格式参见 Intel Manual Vol 3 - 6.11 IDT DESCRIPTORS
    # IDT 描述符包括三种：
    #   - 任务门描述符
    #   - 中断门描述符
    #   - 陷阱门描述符
setup_idt:
    lea ignore_idt, %edx
    mov $0x00080000, %eax   # 0x0008 代码段选择子
    movw %dx, %ax
    movw $0x8e00, %dx       # 0x8e00 标志位 (P=1,DPL=0,32位中断门)
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

hlt:
    hlt

## 中断和异常处理程序
.align 4
page_fault_handler:
    xchg %eax, (%esp)           # (%esp) 是CPU放置的错误码
    push %eax
    push %ecx
	push %edx
	push %ds
	push %es
	push %fs
    
    mov $0x10, %edx             # 数据段选择子
    movw %dx, %ds
    movw %dx, %es
    movw %dx, %fs
    mov %cr2, %edx
    push %edx                   # address
    push %eax                   # error code
    call do_page_fault
    add $8, %esp
    
    pop %fs
	pop %es
	pop %ds
	pop %edx
	pop %ecx
	pop %eax
    iret

# 无错误号
.align 4
divide_error_handler:
    push %eax
    push %ebx
    push %ecx
	push %edx
	push %ds
	push %es
	push %fs
    
    mov $0x10, %edx             # 数据段选择子
    movw %dx, %ds
    movw %dx, %es
    movw %dx, %fs
    push $0                     # address
    push $0                     # error code
    call do_divide_error
    add $8, %esp
    
    pop %fs
	pop %es
	pop %ds
	pop %edx
	pop %ecx
    pop %ebx
	pop %eax
    iret

.align 4
stack_top:
    .long STACK_TOP             # 32-bits offset
    .word 0x10                  # 16-bits selector

.align 2
# GDT的描述符，用来加载到GDTR
.word 0
gdt_desc:
    .word 256*8-1               # 限长：6个*8字节/个=48字节 (0x30-1)
    .long gdt                   # gdt地址

.word 0
idt_desc:
    .word 256*8-1
    .long idt

.align 8
# 全局描述符表
gdt:
    .quad 0x0000000000000000    # 第一个必须为空
    .quad 0x00CF9A000000FFFF    # 4GB的代码段
    .quad 0x00CF92000000FFFF    # 4GB的数据段
    .quad 0x0000000000000000    # 预留
    .fill 252,8,0               # Others

idt:
    .fill 256,8,0

# 由于页目录和页表项的地址都是20位，因此必须在4K对齐
.align 4096
page_dir:
    .fill 1024,4,0
page_table1:
    .fill 1024,4,0
page_table2:
    .fill 1024,4,0
page_table3:
    .fill 1024,4,0
page_table4:
    .fill 1024,4,0

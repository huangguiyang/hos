# 实模式初始化
# 切换到保护模式
# 将 c 移动到地址 0 （会覆盖掉 BIOS 中断）
# 切换到保护模式后不会再返回实模式，所以不会再用到BIOS中断调用
# IBM-PC还需要开启A20地址线才能访问1MB以上的内存
# Loaded at 0x9600:0x0000

.code16

.section .text
.globl _start
_start:
    mov %cs, %ax
    mov %ax, %ds        # 必须要设置DS，16位下类似 [xxx] 寻址默认 DS:[xxx]
    mov %ax, %es
    mov %ax, %ss
    mov $0x5000, %sp    # 20K

    # 准备进入保护模式
    cli

    # 64K开始整体往前移动
    xor %ax, %ax
    cld                 # 清除movsw方向
do_move:
    mov %ax, %es        # destination es:di
    add $0x1000, %ax
    cmp $0x9000, %ax
    jz end_move
    mov %ax, %ds        # source ds:si
    sub %di, %di
    sub %si, %si
    mov $0x8000, %cx    # 64K
    rep
    movsw
    jmp do_move

end_move:
    mov %cs, %ax
    mov %ax, %ds        # 恢复 (do_move修改了)
    mov %ax, %es

    # 加载 IDTR, GDTR
    lidt idt_desc
    lgdt gdt_desc

    call enable_a20     # 开启A20地址线

    mov $0x0001, %ax
    lmsw %ax            # CR0.PE=1 开启保护模式

    # 紧接一个 far jmp
    ljmp $0x08, $0      # 跳到保护模式程序 (Index = 1, GDT, CPL 0)

enable_a20:
    # 开启A20地址线
    # 通过8042键盘控制器引脚的方式
    call wait_8042
    movb $0xad, %al     # 禁止第一个PS/2端口
    outb %al, $0x64

    call wait_8042
    movb $0xd0, %al     # 发命令：准备读取输出端口
    outb %al, $0x64

    call wait_8042_2
    inb $0x60, %al      # 读取数据端口的数据
    push %ax            # 保存数据

    call wait_8042
    movb $0xd1, %al     # 发命令：准备写输出端口
    outb %al, $0x64

    call wait_8042
    pop %ax
    orb $0x02, %al      # 开启A20比特位
    outb %al, $0x60

    call wait_8042
    movb $0xae, %al     # 开启第一个PS/2端口（上面给关闭了）
    outb %al, $0x64

    call wait_8042
    ret

wait_8042:
    inb $0x64, %al      # 读取8042状态寄存器到al
    testb $0x02, %al    # 测试输入缓冲状态（0-空，1-满）
    jnz wait_8042       # 如果满，继续测试
    ret

wait_8042_2:
    inb $0x64, %al
    testb $0x01, %al    # 测试输出缓冲状态（0-空，1-满）
    jz wait_8042_2      # 如果空，继续测试
    ret

# IA-32的段描述符8字节，其中4个字节是段基址，20位段限长
# 段的长度除了段限长，还要乘以粒度（1字节或4K）
# 因此，段长度有1MB或4GB两种。

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

# GDT的描述符，用来加载到GDTR
# Pseudo-Descriptor Format
# 0~15: Limit, 16~47: 32-bit base address
gdt_desc:
    .word 0x0017           # 限长：3*8=24字节 (0x18-1)
    .word 0x6000+gdt,0x9   # gdt地址: 0x9600 + gdt

idt_desc:
    .word 0
    .word 0,0

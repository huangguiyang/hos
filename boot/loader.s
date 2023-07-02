# loaded at 0xF000 (60K)

.include "defines.s"

.code16

.section .text
.globl _start
_start:
    ljmp $0, $relocate_start    # CS = 0

relocate_start:
    mov %cs, %ax
    mov %ax, %ds                # 必须要设置DS，16位下类似[x]寻址默认DS:[x]
    mov %ax, %es
    mov %ax, %ss
    mov $BOOTSEC_ADDR, %sp

loader_ap16:
    jmp loader_bsp16            # will be patched with NOP for APs

    # 每个AP都需要不同的栈，因此这里先不使用栈，推到后面

    cli
    lidt idt_desc32
    lgdt gdt_desc32

    mov $0x0001, %ax
    lmsw %ax

    ljmp $0x08, $prot_ap32

loader_bsp16:
    movw $0x9090, (loader_ap16) # patch with NOP

    call enable_a20             # enable A20 Line

    mov load_kern_msg_len, %cx
    mov $load_kern_msg, %bp
    call print_msg

    call load_kern              # load kernel

    cli                         # fix VMWare
    lidt idt_desc32             # load IDT
    lgdt gdt_desc32             # load GDT

    mov $0x0001, %ax
    lmsw %ax                    # CR0.PE=1 开启保护模式

    ljmp $0x08, $prot_bsp32     # 跳到保护模式程序 (Index = 1, TI=0(GDT), RPL=00)

    # 踩坑：
    # 如果不加载到 64K 边界，BIOS 读取扇区在跨越 64K 边界时会报错 09
    # 查阅后是 DMA access across 64k boundary

    # 大文件跨磁道、磁头，需要处理
    #
    # 以 1.44M 软盘为例：
    #   2个磁头，80磁道/磁头，18扇区/磁道，512字节/扇区
    #   扇区总数 = 2磁头 x 80磁道/磁头 x 18扇区/磁道 = 2880扇区
    #   存储容量 = 512字节/扇区 x 2880扇区 = 1440KB
    #
    #   磁头编号：0-1       (head)
    #   磁道编号：0-79      (cylinder)
    #   扇区编号：1-18      (sector)
    #
    #   扇区的线性地址是这样的：
    #   0头0道1扇区...0头0道18扇区      0-17
    #   1头0道1扇区...1头0道18扇区      18-35
    #   0头1道1扇区...0头1道18扇区      36-53
    #
    # BIOS INT 13H, AH=08H 获取磁盘参数
    # DL: 磁盘索引，00H-7FH 软盘，80H-FFH 硬盘
    # 返回：成功 CF=0，失败 CF=1, AH 错误码
    # BL: 磁盘类型
    # CH: 最大磁道的低8位
    # CL: 0:5 最大扇区数，6:7 最大磁道的高2位
    # DH: 最大磁头数
    # DL: 磁盘个数
    # ES:DI: 磁盘参数表位置
load_kern:
    movb $0x08, %ah         # 读取磁盘参数
    movb $0x00, %dl         # drive 0
    int $0x13
    jc load_kern            # 失败就重试 CF=1
    movb $0, %ch            # 忽略，磁道数下面不会用到
    mov %cx, nsector        # 软盘磁道数不会超过255，CL寄存器bit 6:7肯定是0
    mov $KERNEL_BEG_SEG, %ax
    mov %ax, %es            # es = KERNEL_BEG_SEG
    call read
    ret

    # 要用到的磁盘参数已经保存，开始读取
read:
    mov %es, %ax
    test $0x0fff, %ax       # 目的地址段 es 必须在4K边界
    jnz load_kern_fail
    xor %bx, %bx            # bx = 0

read_1:
    mov %es, %ax
    cmp $KERNEL_END_SEG, %ax       # 是否读取完毕
    jb read_2
    ret

read_2:
    mov nsector, %ax
    sub sector, %ax         # sector = nsector - sector :当前磁道未读扇区数
    mov %ax, %cx
    shl $0x09, %cx          # 字节数 (扇区数 x 512)
    add %bx, %cx
    jnc read_3              # 没超出64k边界
    je read_3               # 刚好在64k边界
    xor %ax, %ax
    sub %bx, %ax
    shr $0x09, %ax          # 扇区数

read_3:
    call read_track
    mov %ax, %cx            # cx = 读取的扇区数
    add sector, %ax
    cmp nsector, %ax        # 当前磁道是否还有未读取的扇区
    jne read_4              # 还有
    mov $0x01, %ax
    sub head, %ax           # !!!!!! 之前误写成 $head, 导致排查很久 !!!!!!
    jne read_5              # 如果刚是磁头0，跳转到读磁头1
    incw track              # 下一个磁道

read_5:
    mov %ax, head           # 保存下一次的磁头号
    xor %ax, %ax            # 当前磁道已读完，清空已读扇区数

read_4:
    mov %ax, sector         # 保存当前已读扇区数
    shl $0x09, %cx          # 上次读取的字节数
    add %cx, %bx
    jnc read_1              # 还没到64K边界

    mov %es, %ax            # 已经到64K边界
    add $0x1000, %ax        # 指向下一个段
    mov %ax, %es
    xor %bx, %bx
    jmp read_1

    # BIOS Read sectors from drive: INT 13h, AH=02h
    # AH: 02h
    # AL: 读取的扇区个数
    # CH: 磁道号
    # CL: 扇区号（从1开始算）
    # DH: 磁头号
    # DL: 磁盘号（00H-7FH 软盘，80H-FFH 硬盘）
    # ES:BX: 目标地址
    #
    # read_track:
    #   track: 当前磁道号
    #   sector: 当前磁道已读扇区数
    #   head: 当前磁头号
    #   AX: 读取的扇区个数
    #   ES:BX: 目标地址
read_track:
    push %ax
    push %bx
    push %cx
    push %dx
    mov track, %dx
    mov sector, %cx
    inc %cx                 # 扇区号
    movb %dl, %ch           # 磁道号
    mov head, %dx           # 磁头
    movb %dl, %dh
    and $0x0100, %dx        # 磁头号只能是0或1, 磁盘号 dl = 0
    movb $0x02, %ah         # read sector
    int $0x13
    jc read_track_fail      # Failed (CF=1)
    pop %dx
    pop %cx
    pop %bx
    pop %ax
    ret

read_track_fail:
    mov $0, %ax
    mov $0, %dx
    int $0x13               # 重置磁盘
    pop %dx
    pop %cx
    pop %bx
    pop %ax
    jmp read_track

load_kern_fail:
    mov load_kern_fail_msg_len, %cx
    mov $load_kern_fail_msg, %bp
    call print_msg
    jmp die

print_msg:
    push %ax
    push %bx
    push %dx
    push %es

    mov %cx, %bx
    # 这个中断会修改 CX,DX
    mov $0x03, %ah
    int $0x10
    mov %bx, %cx

    inc %dh                 # 下一行
    movb $0, %dl

    mov %cs, %ax
    mov %ax, %es
    mov $0x02, %bx
    mov $0x1301, %ax
    int $0x10

    pop %es
    pop %dx
    pop %bx
    pop %ax

    ret

die:
    jmp die

enable_a20:
    # 必须关中断（实测 virtualbox 需要这个）
    cli
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
    sti
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

.align 2
head:
    .word 0                 # 当前磁头号

sector:
    .word KERNEL_SEC_IDX-1  # 当前磁道已读扇区数

track:
    .word 0                 # 当前磁道号

nsector:
    .word 0                 # 每个磁道的扇区个数

load_kern_fail_msg:
    .asciz "Failed to load kernel."
load_kern_fail_msg_len:
    .word . - load_kern_fail_msg

load_kern_msg:
    .asciz "Loading kernel..."
load_kern_msg_len:
    .word . - load_kern_msg

# 段描述符

# 全局描述符表
.align 8
gdt32:
    # [0]第一个必须为空
    .int 0,0

    # [1]代码段, base=0, limit=FFFFF
    # G=1(4K), D/B=1, L=0, S=1, Type=A(Code,RX), DPL=0, P=1
    
    .int 0x0000FFFF
    .int 0x00CF9A00

    # [2]数据段, base=0, limit=FFFFF
    # G=1(4K), D/B=1, L=0, S=1, Type=2(Data,RW), DPL=0, P=1

    .int 0x0000FFFF
    .int 0x00CF9200

    # [3]64位代码段, base=0, limit=FFFFF
    # G=1(4K), D/B=0, L=1, S=1, Type=A(Code,RX), DPL=0, P=1

    .int 0x0000FFFF
    .int 0x00AF9A00

    # [4]数据段, base=0, limit=FFFFF
    # G=1(4K), D/B=1, L=0, S=1, Type=2(Data,RW), DPL=0, P=1

    .int 0x0000FFFF
    .int 0x00CF9200

# GDT的描述符，用来加载到GDTR
# Pseudo-Descriptor Format
# 0~15: Limit, 16~47: 32-bit base address
.word 0
gdt_desc32:
    .word 5*8-1     # 限长
    .int gdt32      # gdt地址

.word 0
idt_desc32:
    .word 0
    .int 0

#
# 32位保护模式
#

.code32

.align 16
prot_ap32:
    mov $0x10, %eax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %ss
    mov %ax, %fs
    mov %ax, %gs
    
    mov $0x200, %esp
    lock xadd %esp, (next_sp)

    call enter32
    call enter64
    ljmp $0x18, $KERNEL_ADDR

.align 16
prot_bsp32:
    mov $0x10, %eax             # 数据段选择符 (index=2)
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %ss
    mov %ax, %fs
    mov %ax, %gs
    mov $BOOTSEC_ADDR, %esp

    call setup_paging32         # Intel要求初始化64位模式之前，必须先开启分页
    call enter32
    call setup_paging64
    call enter64
    ljmp $0x18, $KERNEL_ADDR    # 终于进入64位模式了 (index=3)

    # 初始化32位分页
setup_paging32:
    movl $PAGE_DIR32, %eax              # page dir address
    movl $PAGE_DIR32+0x1000+7, (%eax)   # A=0,PCD=0,PWT=0,U/S=1,R/W=1,P=1
    
    # 初始化页表 [0-1023] 即 0-4MB 内存页
    movl (%eax), %ebx
    and $0xfffff000, %ebx        # ebx = 第一个页表地址
    mov $1024, %ecx
    xor %eax, %eax
    add $3, %eax                # U/S=0,R/W=1,P=1
pte32:
    mov %eax, (%ebx)
    add $0x1000, %eax           # 加4K
    add $4, %ebx
    dec %ecx
    jne pte32
    ret

enter32:
    # 修改CR3和CR0寄存器，开启分页
    # CR3指向页目录，CR0设置PG位
    # 由于页目录4K对齐，直接mov到CR3即可
    mov $PAGE_DIR32, %eax
    mov %eax, %cr3              # PCD=0,PWT=0
    mov %cr0, %eax
    or $0x80000000, %eax        # 最高位是PG (Paging)
    mov %eax, %cr0              # PG=1
    ret

    # 4-Level-Paging
    # 64位模式下CR3是64位，但现在我们在32位模式下，
    # 因此，此时映射表只能在4GB地址空间内
    # 如果需要放在4GB以上地址，需要切到64位后再重新映射
setup_paging64:
     movl $0x1000, %ecx
     mov $PAGE_DIR64, %ebx
     # 4*4K 全部置零
zero_pages64:
     movl $0, (%ebx)
     add $4, %ebx
     dec %ecx
     jne zero_pages64

    mov $PAGE_DIR64, %ebx           # PML4E
    movl $PAGE_DIR64+0x1000+3, (%ebx)
    movl $0, 4(%ebx)

    mov $PAGE_DIR64+0x1000, %ebx    # PDPTE
    movl $PAGE_DIR64+0x2000+3, (%ebx)
    movl $0, 4(%ebx)

    mov $PAGE_DIR64+0x2000, %ebx    # PDE
    movl $PAGE_DIR64+0x3000+3, (%ebx)
    movl $0, 4(%ebx)

    # 初始化第一个PTE，可以映射2MB
    mov $PAGE_DIR64+0x3000, %ebx    # PTE
    mov $512, %ecx
    xor %eax, %eax
    add $3, %eax                    # U/S=0,R/W=1,P=1
pte64:
    mov %eax, (%ebx)
    movl $0, 4(%ebx)
    add $0x1000, %eax               # 加4K
    add $8, %ebx
    dec %ecx
    jne pte64
    ret

    # 开启64位模式步骤（Long Mode）
    # 1.首先进入保护模式，且开启分页
    # 2.关闭分页: CR0.PG = 0
    # 3.开启PAE: CR4.PAE = 1
    # 4.加载四级分页表：CR3 = PML4
    # 5.开启64位模式：IA32_EFER.LME = 1
    # 6.开启分页：CR0.PG = 1
enter64:
    mov %cr0, %eax
    and $0x7fffffff, %eax       # 最高位是PG (Paging)
    mov %eax, %cr0              # PG=0
    
    mov %cr4, %eax
    or $0x00000020, %eax        # PAE=1
    and $0xfffdffff, %eax       # PCIDE=0
    mov %eax, %cr4
    
    # 初始化CR3
    mov $PAGE_DIR64, %eax
    mov %eax, %cr3

    # 查阅Intel手册4，得知IA32_EFER地址为C000_0080
    # 64位寄存器，其中：
    # bit 8: LME (Long Mode Enable)
    # bit 10: LMA (Long Mode Active)
    # MSR指令说明：
    # RDMSR: 读取ECX指定的MSR到EDX:EAX
    # WRMSR: 将EDX:EAX写入ECX指定的MSR
    mov $0xc0000080, %ecx
    rdmsr
    or $0x100, %eax             # IA32_EFER.LME=1
    wrmsr

    mov %cr0, %eax
    or $0x80000000, %eax        # PG=1
    mov %eax, %cr0
    ret

.align 16
next_sp:
    .int TMP_KERNEL_STACK_BASE
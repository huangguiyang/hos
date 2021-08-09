# loaded at 0x9600:0

.code16

.set KSEC, 0x07
.set BEG_SEG, 0x1000
.set END_SEG, 0x9000

.section .text
.globl _start
_start:
    mov %cs, %ax
    mov %ax, %ds                # 必须要设置DS，16位下类似[x]寻址默认DS:[x]
    mov %ax, %es
    mov %ax, %ss
    mov $0x4FF0, %sp            # about 20K

    call load                   # load kern64 to 0x1000:0x0000 (64K)

    # FIX: vmware, 先bios加载完成后再关中断
    #       否则 vmware 下报错；bochs 则正常
    cli

    lidt idt_desc               # load IDT
    lgdt gdt_desc               # load GDT

    call enable_a20

    mov $0x0001, %ax
    lmsw %ax                    # CR0.PE=1 开启保护模式

    # 紧接一个 far jmp
    ljmp $0x08, $_start32       # 跳到保护模式程序 (Index = 1, GDT, CPL 0)

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

    # 大文件跨磁道、磁头（面），需要处理
    #
    # 以 1.44M 软盘为例：
    #   2个面，80磁道/面，18扇区/磁道，512字节/扇区
    #   扇区总数 = 2面 x 80磁道/面 x 18扇区/磁道 = 2880扇区
    #   存储容量 = 512字节/扇区 x 2880扇区 = 1440KB
    #
    #   面编号：0-1
    #   磁道编号：0-79
    #   扇区编号：1-18
    #
    #   扇区的线性地址是这样的：
    #   0面0道1扇区...0面0道18扇区      0-17
    #   1面0道1扇区...1面0道18扇区      18-35
    #   0面1道1扇区...0面1道18扇区      36-53
    #
    # BIOS INT 13H, AH=08H 获取磁盘参数
    # DL: 磁盘索引，00H-7FH 软盘，80H-FFH 硬盘
    # 返回：成功 CF=0，失败 CF=1, AH 错误码
    # BL: 磁盘类型
    # CH: 最大cylinder的低8位   （即磁道，从0算起）
    # CL: 0:5 最大扇区数，6:7 最大cylinder的高2位   （从1算起）
    # DH: 最大磁头数    （从0算起）
    # DL: 磁盘个数
    # ES:DI: 磁盘参数表位置
load:
    movb $0x08, %ah         # 读取磁盘参数
    movb $0x00, %dl         # drive 0
    int $0x13
    jc load                 # 失败就重试 CF=1
    movb $0, %ch            # 忽略，磁道数下面不会用到
    mov %cx, nsector        # 软盘磁道数不会超过255，CL寄存器bit 6:7肯定是0
    mov $BEG_SEG, %ax
    mov %ax, %es
    call read
    ret

    # 要用到的磁盘参数已经保存，开始读取
read:
    mov %es, %ax
    test $0x0fff, %ax       # 由于 c 加载到64k，必须在64k边界
    jne die
    xor %bx, %bx

    # 64k segment boundary
read_1:
    mov %es, %ax
    cmp $END_SEG, %ax       # 是否读取完毕
    jb read_2
    ret

read_2:
    mov nsector, %ax
    sub sector, %ax
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

    # 读取整条磁道到 
    # 目标地址：es:bx
    # AL: 需要读取的扇区数
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
    jc read_fail            # Failed (CF=1)
    pop %dx
    pop %cx
    pop %bx
    pop %ax
    ret

read_fail:
    mov $0, %ax
    mov $0, %dx
    int $0x13               # 重置磁盘
    pop %dx
    pop %cx
    pop %bx
    pop %ax
    jmp read_track

die:
    hlt

.align 2
head:
    .word 0                 # 当前磁头号

sector:
    .word KSEC-1            # 当前磁道已读扇区数

track:
    .word 0                 # 当前磁道号

nsector:
    .word 0                 # 每个磁道的扇区个数

# IA-32的段描述符8字节，其中4个字节是段基址，20位段限长
# 段的长度除了段限长，还要乘以粒度（1字节或4K）
# 因此，段长度有1MB或4GB两种。

# 全局描述符表
.align 8
gdt:
    .word 0,0,0,0       # 第一个必须为空
    
    .word 0xFFFF        # limit
    .word 0x6000        # 基址
    .word 0x9A09        # 代码段，rx权限
    .word 0x00CF        # 粒度-4K，32位操作数

    .word 0xFFFF        # limit
    .word 0x6000        # 基址
    .word 0x9209        # 数据段，rw权限
    .word 0x00CF        # 粒度-4K，32位操作数

    .word 0xFFFF        # limit
    .word 0x0000        # 基址
    .word 0x9200        # 数据段，rw权限
    .word 0x00CF        # 粒度-4K，32位操作数

    # 0-4G代码段
    .word 0xFFFF        # limit
    .word 0x0000        # 基址
    .word 0x9A00        # 代码段，rx权限
    .word 0x00AF        # 粒度-4K，32位操作数 (long mode)

    # 0-4G数据段
    .word 0xFFFF        # limit
    .word 0x0000        # 基址
    .word 0x9200        # 数据段，rw权限
    .word 0x00CF        # 粒度-4K，32位操作数

# GDT的描述符，用来加载到GDTR
# Pseudo-Descriptor Format
# 0~15: Limit, 16~47: 32-bit base address
.word 0
gdt_desc:
    .word 6*8-1                 # 限长
    .word 0x6000+gdt,0x9        # gdt地址

.word 0
idt_desc:
    .word 0
    .word 0,0

#
# 32位保护模式
#

.code32

.set STACK_TOP, 0x9FFF0     # about 640K

_start32:
    mov $0x10, %eax         # 数据段选择子
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    lss stack_top, %esp

    push $paging_ok
    jmp setup_paging            # Intel要求初始化64位模式之前，必须先开启分页
paging_ok:
    mov $0x80000008, %eax
    cpuid
    movb %al, phy_addr_bits     # 物理地址位数，即 MAXPHYADDR
    movb %ah, line_addr_bits    # 线性地址位数（通常是48）
    push $paging_ok64
    jmp setup_paging64
paging_ok64:
    ljmp $0x20, $0x10000        # 跳到64K处，终于进入64位模式了

stack_top:
    .long STACK_TOP             # 32-bits offset
    .word 0x18                  # 16-bits selector

    # 初始化32位分页
    # 页目录表地址0，因为BIOS已经用不到了
setup_paging:
    # 修改数据段
    mov $0x18, %eax
    mov %ax, %ds

    xor %eax, %eax
    movl $0x1000+7, (%eax)      # A=0,PCD=0,PWT=0,U/S=1,R/W=1,P=1
    
    # 初始化页表 [0-1023] 即 0-4MB 内存页
    movl (%eax), %ebx
    and $0xfffff000, %ebx        # ebx = 第一个页表地址
    mov $1024, %ecx
    xor %eax, %eax
    add $3, %eax                # U/S=0,R/W=1,P=1
rp_pte:
    mov %eax, (%ebx)
    add $0x1000, %eax           # 加4K
    add $4, %ebx
    dec %ecx
    jne rp_pte

    # 恢复数据段
    mov $0x10, %eax
    mov %ax, %ds

    # 修改CR3和CR0寄存器，开启分页
    # CR3指向页目录，CR0设置PG位
    # 由于页目录4K对齐，直接mov到CR3即可
    mov $0, %eax
    mov %eax, %cr3              # PCD=0,PWT=0
    mov %cr0, %eax
    or $0x80000000, %eax        # 最高位是PG (Paging)
    mov %eax, %cr0              # PG=1
    ret

    # 开启64位模式步骤
    # 1.首先进入保护模式，且开启分页
    # 2.关闭分页: CR0.PG = 0
    # 3.开启PAE: CR4.PAE = 1
    # 4.加载四级分页表：CR3 = PML4
    # 5.开启64位模式：IA32_EFER.LME = 1
    # 6.开启分页：CR0.PG = 1
setup_paging64:
    mov %cr0, %eax
    and $0x7fffffff, %eax       # 最高位是PG (Paging)
    mov %eax, %cr0              # PG=0
    
    mov %cr4, %eax
    or $0x00000020, %eax        # PAE=1
    and $0xfffdffff, %eax       # PCIDE=0
    mov %eax, %cr4

    call setup_4_level_paging

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

    # 64位模式下CR3是64位，但现在我们在32位模式下！
    # 因此，此时映射表只能在4GB地址空间内
    # 如果需要放在4GB以上地址，需要切到64位后再重新映射
setup_4_level_paging:
    # 修改数据段
    mov $0x18, %eax
    mov %ax, %ds

    mov $0x100000, %ebx         # 1MB       PML4E
    movl $0x101000+3, (%ebx)
    movl $0, 4(%ebx)

    mov $0x101000, %ebx         # 1MB+4k    PDPTE
    movl $0x102000+3, (%ebx)
    movl $0, 4(%ebx)

    mov $0x102000, %ebx         # 1MB+8k    PDE
    movl $0x103000+3, (%ebx)
    movl $0, 4(%ebx)

    # 初始化第一个PTE，可以映射2MB
    mov $0x103000, %ebx         # 1MB+12k   PTE
    mov $512, %ecx
    xor %eax, %eax
    add $3, %eax                # U/S=0,R/W=1,P=1
rp_pte64:
    mov %eax, (%ebx)
    movl $0, 4(%ebx)
    add $0x1000, %eax           # 加4K
    add $8, %ebx
    dec %ecx
    jne rp_pte64

    # 恢复数据段
    mov $0x10, %eax
    mov %ax, %ds

    # 初始化CR3
    mov $0x100000, %eax
    mov %eax, %cr3
    ret

phy_addr_bits:
    .byte 0
line_addr_bits:
    .byte 0

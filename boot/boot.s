# loaded at 0x9600:0000

.code16

.set KSEC, 0x0C
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

    call load16                 # load kern16 to 0x0100:0x0000 (4K)
    call load64                 # load kern64 to 0x1000:0x0000 (64K)
    call enable_a20             # enable A20 Line

    ljmp $0, $0x1000            # jump to kern16

load16:
    xor %bx, %bx
    mov $0x0100, %ax
    mov %ax, %es            # destination es:bx
    movb $0x02, %ah         # read sectors command
    movb $8, %al            # number of sectors
    movb $0, %ch            # cylinder 0
    movb $5, %cl            # sector number (count from 1)
    mov $0, %dx             # head 0, drive 0
    int $0x13
    jnc load16_ok           # jump if CF=0 (successful)

    mov $0, %ax             # reset disk
    mov $0, %dx
    int $0x13
    jmp load16

load16_ok:
    ret

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
load64:
    movb $0x08, %ah         # 读取磁盘参数
    movb $0x00, %dl         # drive 0
    int $0x13
    jc load64               # 失败就重试 CF=1
    movb $0, %ch            # 忽略，磁道数下面不会用到
    mov %cx, nsector        # 软盘磁道数不会超过255，CL寄存器bit 6:7肯定是0
    mov $BEG_SEG, %ax
    mov %ax, %es
    call read
    ret

    # 要用到的磁盘参数已经保存，开始读取
read:
    mov %es, %ax
    test $0x0fff, %ax       # 由于加载到64k，必须在64k边界
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
    .word KSEC              # 当前磁道已读扇区数

track:
    .word 0                 # 当前磁道号

nsector:
    .word 0                 # 每个磁道的扇区个数

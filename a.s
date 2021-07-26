# loaded at address 0x7c00
# 将 b 移动到地址 0x9600:0x0000 (600k)
# 将堆栈设置为 0x9600:0x5000 (620K)
# 将 c 移动到地址 0x1000:0x0000
# 重要：不直接移动到 0 是因为移动过程中需要调用 BIOS 中断
# 然后跳转到 b 执行 

# work in 16 bit mode
.code16

.set BSEG, 0x9600           # 0x9600:0000 = 600k
.set BSEC, 0x03             # b所在开始扇区号
.set BNSEC, 0x04            # b占用的扇区数
.set CSEG, 0x1000           # 0x1000:0000 = 64K
.set CENDSEG, 0x4000        # 0x9000:0000 = 64K + 192K = 256K
.set CSEC, 0x07             # c所在开始扇区号

.section .text
.globl _start
_start:
    ljmp $0x07c0, $go       # 设置CS:IP
go:
    mov %cs, %ax
    mov %ax, %ds            # 设置DS，内存寻址
    mov %ax, %es
    mov $BSEG, %ax
    mov %ax, %ss
    mov $0x5000, %sp        # 0x9600:20K

    # 读取b
    # 读取扇区有两种方式：一种直接使用BIOS接口；一种直接使用IN/OUT指令
    # BIOS INT 13h, AH=02h Read sectors from drive
    # 其中 sector 较为特殊，从1开始算起
    # AL = 扇区数
    # CH = cylinder（柱面，即磁道号）
    # CL = 扇区号
    # DH = head
    # DL = 磁盘号（00H-7FH 软盘，80H-FFH 硬盘）
load_b:
    xor %bx, %bx
    mov $BSEG, %ax
    mov %ax, %es           # destination es:bx
    movb $0x02, %ah        # read sectors
    movb $BNSEC, %al       # number of sectors
    mov $BSEC, %cx         # cylinder 0, sector
    mov $0, %dx            # head 0, drive 0
    int $0x13
    jnc load_ok            # jump if CF=0 (successful)

    mov $0, %ax            # 重置磁盘
    mov $0, %dx
    int $0x13
    jmp load_b

load_ok:
    # 读取c
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
    #       01H: 360KB, 40 tracks, 5.25"
    #       02H: 1.2MB, 80 tracks, 5.25"
    #       03H: 720KB, 80 tracks, 3.5"
    #       04H: 1.44M, 80 tracks, 3.5"
    # CH: 最大cylinder的低8位   （即磁道，从0算起）
    # CL: 0:5 最大扇区数，6:7 最大cylinder的高2位   （从1算起）
    # DH: 最大磁头数    （从0算起）
    # DL: 磁盘个数
    # ES:DI: 磁盘参数表位置
load_c:
    movb $0x08, %ah         # 读取磁盘参数
    movb $0x00, %dl         # drive 0
    int $0x13
    jc load_c               # 失败就重试 CF=1

    movb $0, %ch            # 忽略，磁道数下面不会用到
    mov %cx, nsector        # 软盘磁道数不会超过255，CL寄存器bit 6:7肯定是0

    mov $CSEG, %ax
    mov %ax, %es
    call read
loop:
    jmp loop
    ljmp $BSEG, $0          # jump to b

    # 要用到的磁盘参数已经保存，开始读取
read:
    mov %es, %ax
    test $0x0fff, %ax       # 由于 c 加载到64k，必须在64k边界
    jne die
    xor %bx, %bx

    # 64k segment boundary
read_1:
    mov %es, %ax
    cmp $CENDSEG, %ax       # 是否读取完毕
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
    sub $head, %ax
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
    call print_dot
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

print_dot:
    push %ax
    push %bx
    push %cx
    push %dx
    push %es
    push %bp

    # 打印字符串
    # al: 模式
    # bh: 页号
    # bl: 颜色属性 (4bit background | 4bit foreground)
    # cx: 字符个数
    # dh: 行
    # dl: 列
    # es:bp - 字符串指针

    movb line, %dh
    movb column, %dl
    cmp $80, %dl
    jne doput
    incb %dh
    movb $0, %dl
    movb %dh, line

doput:
    mov %cs, %ax
    mov %ax, %es
    mov $0x02, %bx
    #mov $0, %dx
    mov $1, %cx
    mov $msg, %bp
    mov $0x1301, %ax
    int $0x10
    
    incb %dl
    movb %dl, column
    pop %bp
    pop %es
    pop %dx
    pop %cx
    pop %bx
    pop %ax
    ret

msg:
    .byte '.'

line:
    .byte 0
column:
    .byte 0

die:
    hlt

    #
    # 重要：需要对齐2字节，不然会产生很难排查出来的bug!!!
    #
.align 2
head:
    .word 0                 # 当前磁头号

sector:
    .word CSEC-1            # 当前磁道已读扇区数

track:
    .word 0                 # 当前磁道号

nsector:
    .word 0                 # 每个磁道的扇区个数

.org 510, 0
boot_sig:
    .word 0xAA55

# 实模式初始化
# loaded at 0x0A00:0x0000 (40K)
# 切换到保护模式

.code16

.set STACK_SEG, 0x0280      # 10K
.set SEC32, 0x7             # start of setup32

.section .text
.globl _start
_start:
    mov %cs, %ax
    mov %ax, %ds
    mov %ax, %es
    mov $STACK_SEG, %ax
    mov %ax, %ss
    mov $0x5000, %sp        # 0x0280:20K
    hlt

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
read_drive_params:
    movb $0x08, %ah         # 读取磁盘参数
    movb $0x00, %dl         # drive 0
    int $0x13
    movb $0, %ch            # 忽略，磁道数下面不会用到
    mov %cx, nsector        # 软盘磁道数不会超过255，CL寄存器bit 6:7肯定是0
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
    # 读取扇区
    # ax: 绝对扇区号
    # cx: 扇区数
    # es:bx 目的地址
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
    .word CSEC-1            # 当前磁道已读扇区数

track:
    .word 0                 # 当前磁道号

nsector:
    .word 0                 # 每个磁道的扇区个数
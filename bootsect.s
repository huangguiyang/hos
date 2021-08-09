# loaded at 0x7c00

.code16

.section .text
.globl _start
_start:
    .byte 0xeb, 0x58, 0x90              # 跳转到5A，与FAT32兼容

.org 0x5a, 0
label_5A:
    # 读取扇区有两种方式：一种直接使用BIOS接口；一种直接使用IN/OUT指令
    # BIOS INT 13h, AH=02h Read sectors from drive
    # 其中 sector 较为特殊，从1开始算起
    # AL = 扇区数
    # CH = cylinder（柱面，即磁道号）
    # CL = 扇区号
    # DH = head
    # DL = 磁盘号（00H-7FH 软盘，80H-FFH 硬盘）
load:
    xor %bx, %bx
    mov $0x9600, %ax        # 600K
    mov %ax, %es            # destination es:bx
    movb $0x02, %ah         # read sectors
    movb $0x04, %al         # number of sectors
    movb $0, %ch            # cylinder 0
    movb $0x03, %cl         # sector number
    mov $0, %dx             # head 0, drive 0
    int $0x13
    jnc load_ok             # jump if CF=0 (successful)

    mov $0, %ax             # 重置磁盘
    mov $0, %dx
    int $0x13
    jmp load

load_ok:
    ljmp $0x9600, $0

.org 426, 0
boot_tab:
    # location information for 'boot' file
    # format: 
    # [0]nsectors, [1]cylinder, [2]head, [3]sector
    # ...
    # 0,0,0,0

.org 446, 0
    # partition table (64 bytes)

.org 510, 0
boot_sig:
    .word 0xAA55

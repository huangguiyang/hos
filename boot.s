# 引导扇区
# loaded at 0x7c00

# work in 16 bit mode
.code16

.set SETUP_SEG, 0x0A00      # 40K
.set STACK_SEG, 0x0280      # 10K
.set NSEC, 0x04             # number of setup sectors
.set SEC, 0x3               # start sector no.

.section .text
.globl _start
_start:
    ljmp $0x07c0, $go       # 设置CS:IP
go:
    mov %cs, %ax
    mov %ax, %ds            # 设置DS，内存寻址
    mov %ax, %es
    mov $STACK_SEG, %ax
    mov %ax, %ss
    mov $0x5000, %sp        # 0x0280:20K

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
    mov $SETUP_SEG, %ax
    mov %ax, %es           # destination es:bx
    movb $0x02, %ah        # read sectors
    movb $NSEC, %al        # number of sectors
    movb $0, %ch           # cylinder 0
    movb $SEC, %cl         # sector
    mov $0, %dx            # head 0, drive 0
    int $0x13
    jnc load_ok            # jump if CF=0 (successful)

    mov $0, %ax            # 重置磁盘
    mov $0, %dx
    int $0x13
    jmp load

load_ok:
    ljmp $SETUP_SEG, $0     # jump to setup

.org 510, 0
boot_sig:
    .word 0xAA55

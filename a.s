# loaded at address 0x7c00

# work in 16 bit mode
.code16

.section .text
.globl _start
_start:
    ljmp $0x07c0, $go       # 设置CS:IP
go:
    movw %cs, %ax
    movw %ax, %ds           # 设置DS，内存寻址
    movw %ax, %es
    movw %ax, %ss

    # 读取 b 到 0x8000 (32k)
    # 读取扇区有两种方式：一种直接使用BIOS接口；一种直接使用IN/OUT指令
    # BIOS INT 13h, AH=02h Read sectors from drive
    # 其中 sector 较为特殊，从1开始算起
load_b:
    xorw %bx, %bx
    movw $0x0800, %ax
    movw %ax, %es           # destination 0x0800:0000
    movb $0x02, %ah         # read sectors
    movb $0x04, %al         # number of sectors
    movw $0x0003, %cx       # cylinder 0, sector 3
    movw $0, %dx            # head 0, drive 0
    int $0x13
    jnc load_c              # jump if CF=0 (successful)

    movw $0, %ax            # 重置磁盘
    movw $0, %dx
    int $0x13
    jmp load_b

    # 读取 c 到 0x10000 (64k)
    # 大文件跨磁道、柱面，需要处理
load_c:
    # 读取磁盘参数
    movb $0x08, %ah         # 读取磁盘参数
    movb $0x00, %dl         # drive 0
    int $0x13

    xorw %bx, %bx
    movw $0x0C00, %ax
    movw %ax, %es           # destination 0x0C00:0000
    movb $0x02, %ah         # read sectors
    movb $0x04, %al         # number of sectors
    movw $0x0007, %cx       # cylinder 0, sector 7
    movw $0, %dx            # head 0, drive 0
    int $0x13
    jnc load_ok              # jump if CF=0 (successful)

    movw $0, %ax            # 重置磁盘
    movw $0, %dx
    int $0x13
    jmp load_c

load_ok:
    ljmp $0x0800, $0        # jump to setup

.org 510, 0
boot_sig:
    .word 0xAA55

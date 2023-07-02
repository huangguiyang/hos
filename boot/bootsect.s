# loaded at 0x7c00 (31K)

.include "defines.s"

.code16

.section .text
.globl _start
_start:
    .byte 0xeb, 0x58, 0x90              # 跳转到5A，与FAT32兼容

.org 0x5a, 0
label_5A:
    mov %cs, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %ss
    mov $BOOTSEC_ADDR, %sp

    # clear screen
    mov $0x03, %ax
    int $0x10

    # print message
    call print_msg

    # 读取扇区有两种方式：一种直接使用BIOS接口；一种直接使用IN/OUT指令
    # BIOS INT 13h, AH=02h Read sectors from drive
    # 其中 sector 较为特殊，从1开始算起
    # AL = 扇区数
    # CH = cylinder（柱面，即磁道号）
    # CL = 扇区号
    # DH = head
    # DL = 磁盘号（00H-7FH 软盘，80H-FFH 硬盘）
load:
    xor %ax, %ax
    mov %ax, %es
    mov $LOADER_ADDR, %bx       # destination es:bx           
    movb $0x02, %ah             # read sectors command
    movb $LOADER_NSECS, %al     # number of sectors
    movb $0, %ch                # cylinder 0
    movb $LOADER_SEC_IDX, %cl   # sector number (count from 1)
    mov $0, %dx                 # head 0, drive 0
    int $0x13
    jnc load_ok                 # jump if CF=0 (successful)

    mov $0, %ax                 # reset disk
    mov $0, %dx
    int $0x13
    jmp load

load_ok:
    ljmp $0, $LOADER_ADDR       # jump to loader

print_msg:
    # 获取当前光标位置
    # CH: Start scan line
    # CL: End scan line
    # DH: row
    # DL: column
    mov $0x03, %ah
    int $0x10

    # 打印字符串：int 10h, ah=13h
    # al: 模式
    # bh: 页号
    # bl: 颜色属性 (4bit background | 4bit foreground)
    # cx: 字符个数
    # dh: 行
    # dl: 列
    # es:bp - 字符串指针
    mov %cs, %ax
    mov %ax, %es
    mov $0x02, %bx
    mov msg_len, %cx
    mov $msg, %bp
    mov $0x1301, %ax
    int $0x10
    ret

msg:
    .asciz "Booting..."
msg_len:
    .word . - msg

.org 446, 0
    # partition table (64 bytes)

.org 510, 0
boot_sig:
    .word 0xAA55

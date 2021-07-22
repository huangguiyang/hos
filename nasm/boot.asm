;; 引导扇区代码
;; PC初始化时第一个扇区被加载到0x7c00

SETUP_SEG equ 0x0800
NUM_SECS equ 2

org 0x7c00
section .text
start:
load_setup:
    ;; 读取setup到0x8000
    ;; 读取扇区有两种方式：一种直接使用BIOS接口；一种直接使用IN/OUT指令
    ;; BIOS INT 13h, AH=02h Read sectors from drive
    ;; 其中 sector 较为特殊，从1开始算起
    xor bx, bx
    mov ax, SETUP_SEG
    mov es, ax       ;; destination 0x0800:0000
    mov ah, 0x02
    mov al, NUM_SECS
    mov cx, 0x0002          ;; cylinder 0, sector 2
    mov dx, 0               ;; head 0, drive 0
    int 0x13
    jnc load_ok             ;; jump if CF=0 (successful)
    ;; 重置磁盘
    mov ax, 0
    mov dx, 0
    int 0x13
    jmp load_setup

load_ok:
    jmp SETUP_SEG:0


times 510-($-$$) db 0
boot_sig:
    dw  0xAA55

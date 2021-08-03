# loaded at 0x7c00

.code16

.section .text
.globl _start
_start:
    ljmp $0x07c0, $go       # 设置CS:IP
go:
    hlt

.org 446, 0
    # partition table (64 bytes)

.org 510, 0
boot_sig:
    .word 0xAA55

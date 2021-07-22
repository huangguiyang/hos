# 32位保护模式
# 加载到 0xC000 (48K)

.code32

.section .text
.globl _start, sti
_start:
    movw $0x10, %ax         # 数据段选择子
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %fs
    movw %ax, %gs
    lss stack_top, %esp

    movl $0xb8000, %ebx
    movb $0x43, %al
    movb $0x0F, %ah
    movw %ax, (%ebx)

    call main
    hlt

sti:
    sti
    ret

# 16-bits selector
# 32-bits offset
stack_top:
    .long 0xA0000           # 640K
    .word 0x10
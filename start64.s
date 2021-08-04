# loaded at 0x10000 (64K)

.code64

.section .text
.globl _start
_start:
    movl $0x28, %eax            # 数据段选择符
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    hlt

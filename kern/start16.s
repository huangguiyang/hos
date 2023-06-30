# loaded at 0x0100:0x0000 (4K)

.code16

.set KERN16_OFF, 0x1000

.section .text
.globl _start
_start:
    mov %cs, %ax
    mov %ax, %ds                # 必须要设置DS，16位下类似[x]寻址默认DS:[x]
    mov %ax, %es
    mov %ax, %ss
    mov $0x4FF0, %sp            # about 20K

    # FIX: vmware, 先bios加载完成后再关中断
    #       否则 vmware 下报错；bochs 则正常
    cli

    lidt idt_desc               # load IDT
    lgdt gdt_desc               # load GDT

    mov $0x0001, %ax
    lmsw %ax                    # CR0.PE=1 开启保护模式

    # 紧接一个 far jmp
    ljmp $0x08, $_start32       # 跳到保护模式程序 (Index = 1, TI=0(GDT), RPL=00)


# 段描述符

# 全局描述符表
.align 8
gdt:
    # [0]第一个必须为空
    .word 0,0,0,0

    # [1]代码段, base=0, limit=FFFFF
    # G=1(4K), D/B=1, L=0, S=1, Type=A(Code,RX), DPL=0, P=1
    
    .word 0xFFFF
    .word 0x0000
    .word 0x9A00
    .word 0x00CF

    # [2]数据段, base=0, limit=FFFFF
    # G=1(4K), D/B=1, L=0, S=1, Type=2(Data,RW), DPL=0, P=1

    .word 0xFFFF
    .word 0x0000
    .word 0x9200
    .word 0x00CF

    # [3]64位代码段, base=0, limit=FFFFF
    # G=1(4K), D/B=0, L=1, S=1, Type=A(Code,RX), DPL=0, P=1

    .word 0xFFFF
    .word 0x0000
    .word 0x9A00
    .word 0x00AF

    # [4]数据段, base=0, limit=FFFFF
    # G=1(4K), D/B=1, L=0, S=1, Type=2(Data,RW), DPL=0, P=1

    .word 0xFFFF
    .word 0x0000
    .word 0x9200
    .word 0x00CF

# GDT的描述符，用来加载到GDTR
# Pseudo-Descriptor Format
# 0~15: Limit, 16~47: 32-bit base address
.word 0
gdt_desc:
    .word 5*8-1             # 限长
    .long gdt               # gdt地址

.word 0
idt_desc:
    .word 0
    .long 0

#
# 32位保护模式
#

.code32

.set STACK_TOP, 0x9FFF0     # about 640K
.set PAGE_DIR, 0x2000       # 8K
.set PAGE_DIR64, 0x100000   # 1M

.align 16
_start32:
    mov $0x10, %eax         # 数据段选择符 (index=2)
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    lss stack_top, %esp

    call setup_paging            # Intel要求初始化64位模式之前，必须先开启分页
    call enter64

    ljmp $0x18, $0x10000        # 终于进入64位模式了 (index=3)

stack_top:
    .long STACK_TOP             # 32-bits offset
    .word 0x10                  # 16-bits selector

    # 初始化32位分页
setup_paging:
    movl $PAGE_DIR, %eax          # page dir address
    movl $PAGE_DIR+0x1000+7, (%eax)  # A=0,PCD=0,PWT=0,U/S=1,R/W=1,P=1
    
    # 初始化页表 [0-1023] 即 0-4MB 内存页
    movl (%eax), %ebx
    and $0xfffff000, %ebx        # ebx = 第一个页表地址
    mov $1024, %ecx
    xor %eax, %eax
    add $3, %eax                # U/S=0,R/W=1,P=1
pte:
    mov %eax, (%ebx)
    add $0x1000, %eax           # 加4K
    add $4, %ebx
    dec %ecx
    jne pte

    # 修改CR3和CR0寄存器，开启分页
    # CR3指向页目录，CR0设置PG位
    # 由于页目录4K对齐，直接mov到CR3即可
    mov $0x2000, %eax
    mov %eax, %cr3              # PCD=0,PWT=0
    mov %cr0, %eax
    or $0x80000000, %eax        # 最高位是PG (Paging)
    mov %eax, %cr0              # PG=1
    ret

    # 开启64位模式步骤
    # 1.首先进入保护模式，且开启分页
    # 2.关闭分页: CR0.PG = 0
    # 3.开启PAE: CR4.PAE = 1
    # 4.加载四级分页表：CR3 = PML4
    # 5.开启64位模式：IA32_EFER.LME = 1
    # 6.开启分页：CR0.PG = 1
enter64:
    mov %cr0, %eax
    and $0x7fffffff, %eax       # 最高位是PG (Paging)
    mov %eax, %cr0              # PG=0
    
    mov %cr4, %eax
    or $0x00000020, %eax        # PAE=1
    and $0xfffdffff, %eax       # PCIDE=0
    mov %eax, %cr4

    call setup_paging64

    # 查阅Intel手册4，得知IA32_EFER地址为C000_0080
    # 64位寄存器，其中：
    # bit 8: LME (Long Mode Enable)
    # bit 10: LMA (Long Mode Active)
    # MSR指令说明：
    # RDMSR: 读取ECX指定的MSR到EDX:EAX
    # WRMSR: 将EDX:EAX写入ECX指定的MSR
    mov $0xc0000080, %ecx
    rdmsr
    or $0x100, %eax             # IA32_EFER.LME=1
    wrmsr

    mov %cr0, %eax
    or $0x80000000, %eax        # PG=1
    mov %eax, %cr0
    ret

    # 4-Level-Paging
    # 64位模式下CR3是64位，但现在我们在32位模式下，
    # 因此，此时映射表只能在4GB地址空间内
    # 如果需要放在4GB以上地址，需要切到64位后再重新映射
setup_paging64:
    mov $PAGE_DIR64, %ebx           # PML4E
    movl $PAGE_DIR64+0x1000+3, (%ebx)
    movl $0, 4(%ebx)

    mov $PAGE_DIR64+0x1000, %ebx    # PDPTE
    movl $PAGE_DIR64+0x2000+3, (%ebx)
    movl $0, 4(%ebx)

    mov $PAGE_DIR64+0x2000, %ebx    # PDE
    movl $PAGE_DIR64+0x3000+3, (%ebx)
    movl $0, 4(%ebx)

    # 初始化第一个PTE，可以映射2MB
    mov $PAGE_DIR64+0x3000, %ebx    # PTE
    mov $512, %ecx
    xor %eax, %eax
    add $3, %eax                    # U/S=0,R/W=1,P=1
pte64:
    mov %eax, (%ebx)
    movl $0, 4(%ebx)
    add $0x1000, %eax               # 加4K
    add $8, %ebx
    dec %ecx
    jne pte64

    # 初始化CR3
    mov $PAGE_DIR64, %eax
    mov %eax, %cr3
    ret
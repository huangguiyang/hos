
print:
    # 获取当前光标位置
    # 返回：dh-行号，dl-列号
    movb $0x03, %ah
    int $0x10

    # 打印字符串
    # al: 模式
    # bh: 页号
    # bl: 颜色属性 (4bit background | 4bit foreground)
    # cx: 字符个数
    # dh: 行
    # dl: 列
    # es:bp - 字符串指针
    movw %cs, %ax
    movw %ax, %es
    movw $0x02, %bx
    #movw $0, %dx
    movb msglen, %cx
    movw $msg, %bp
    movw $0x1301, %ax
    int $0x10

msg:
    .ascii "Hello, world!"
msglen:
    .byte .-msg
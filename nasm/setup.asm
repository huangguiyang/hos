;; 实模式初始化
;; 由boot.asm加载到32k处

;org 0x8000
section .text
start:
    ;; 获取当前光标位置
    ;; dh: 行号
    ;; dl: 列号
    mov ah, 0x03
    int 0x10

    ;; 打印字符串：int 10h, ah=13h
    ;; al: 模式
    ;; bh: 页号
    ;; bl: 颜色属性 (4bit background | 4bit foreground)
    ;; cx: 字符个数
    ;; dh: 行
    ;; dl: 列
    ;; es:bp - 字符串指针
    mov ax, cs
    mov es, ax
    mov bx, 0x02    ;; 绿色，黑底
    ;mov dx, 0
    mov cx, 13
    mov bp, msg
    mov ax, 0x1301
    int 0x10
    hlt

msg:
    db 'Hello, setup!'

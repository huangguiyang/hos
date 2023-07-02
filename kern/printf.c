#include "kern.h"

#define LINE_MAX    25
#define COLUMN_MAX  80
#define PAGE_MAX    8

#define GREEN_COLOR 0x02

#define TAB_WITDH 8

// Color VGA
static char *vga_buffer = (char *)0xb8000;
static int cursor_line;
static int cursor_column;
static char print_buffer[1024];

struct fmt {
    char *buf;
    char *to;
    char *stop;
};

static void fmt_init(struct fmt *f, char *str, int size)
{
    f->buf = str;
    f->to = str;
    f->stop = str + size;
}

static void fmt_fini(struct fmt *f)
{
    if (f->to < f->stop)
        *f->to = 0;
    else
        *(f->stop - 1) = 0;
}

static void fmt_putc(struct fmt *f, int c)
{
    if (c == '\t') {
        int i = 0;
        while (f->to < f->stop && i < TAB_WITDH) {
            *f->to++ = ' ';
            i++;
        }
    } else {
        if (f->to < f->stop)
            *f->to++ = c;
    }
}

static void fmt_puts(struct fmt *f, char *s)
{
    for (; *s; s++)
        fmt_putc(f, *s);
}

// %c,%d,%x,%s,%p,%ld,%lx
int vsnprintf(char *str, int size, const char *fmt, va_list ap)
{
    int c;
    unsigned int u;
    long l;
    unsigned long ul;
    char *s;
    char b[64];
    struct fmt f;

    fmt_init(&f, str, size);
    for (; *fmt; fmt++) {
        if (*fmt != '%') {
            // put char
            fmt_putc(&f, *fmt);
            continue;
        }
        
        switch (*++fmt) {
        case 'c':
            c = va_arg(ap, int);
            fmt_putc(&f, c);
            break;
        
        case 'd':
            c = va_arg(ap, int);
            if (c == INT_MIN)
                u = (unsigned int)INT_MAX + 1;
            else if (c < 0)
                u = -c;
            else
                u = c;
            s = b + sizeof(b) - 1;
            *s = 0;
            do {
                *--s = u%10 + '0';
                u /= 10;
            } while (u);
            if (c < 0)
                *--s = '-';
            fmt_puts(&f, s);
            break;
        
        case 'x':
            u = va_arg(ap, int);
            s = b + sizeof(b) - 1;
            *s = 0;
            do {
                c = u & 0x0f;
                if (c >= 10)
                    *--s = c - 10 + 'A';
                else
                    *--s = c + '0';
                u >>= 4;
            } while (u);
            fmt_puts(&f, s);
            break;

        case 'p':
            ul = va_arg(ap, unsigned long);
            s = b + sizeof(b) - 1;
            *s = 0;
            do {
                c = ul & 0x0f;
                if (c >= 10)
                    *--s = c - 10 + 'A';
                else
                    *--s = c + '0';
                ul >>= 4;
            } while (ul);
            *--s = 'x';
            *--s = '0';
            fmt_puts(&f, s);
            break;
        
        case 's':
            s = va_arg(ap, char *);
            fmt_puts(&f, s);
            break;

        case 'l':
            fmt++;
            if (*fmt == 'd') {
                l = va_arg(ap, long);
                if (l == LONG_MIN)
                    ul = (unsigned long)LONG_MAX + 1;
                else if (l < 0)
                    ul = -l;
                else
                    ul = l;
                s = b + sizeof(b) - 1;
                *s = 0;
                do {
                    *--s = ul % 10 + '0';
                    ul /= 10;
                } while (ul);
                if (l < 0)
                    *--s = '-';
                fmt_puts(&f, s);
            } else if (*fmt == 'x') {
                ul = va_arg(ap, unsigned long);
                s = b + sizeof(b) - 1;
                *s = 0;
                do {
                    c = ul & 0x0f;
                    if (c >= 10)
                        *--s = c - 10 + 'A';
                    else
                        *--s = c + '0';
                    ul >>= 4;
                } while (ul);
                fmt_puts(&f, s);
            }
            break;
        
        default:
            fmt_putc(&f, *fmt);
            break;
        }
    }

    fmt_fini(&f);
    return puts(str);
}

int puts(char *str)
{
    char *p;

    for (p = str; *p; p++)
        putc(*p);
    return (p - str);
}

static void out_byte(char *buffer, int ch, int color)
{
    *(short *)buffer = ((color & 0xff) << 8) | (ch & 0xff);
}

void clear_screen(void)
{
    short *dst = (short *)vga_buffer;
    for (int i = 0; i < LINE_MAX * COLUMN_MAX; i++)
            *dst++ = 0;
}

static void scroll_up(void)
{
    short *dst = (short *)vga_buffer;
    short *src = dst + COLUMN_MAX;
    int i;

    for (i = 0; i < (LINE_MAX - 1) * COLUMN_MAX; i++)
        *dst++ = *src++;

    dst = (short *)vga_buffer + (COLUMN_MAX * (LINE_MAX - 1));
    for (i = 0; i < COLUMN_MAX; i++)
        *dst++ = 0;
}

static void incline(void)
{
    cursor_line++;
    cursor_column = 0;
    if (cursor_line >= LINE_MAX) {
        scroll_up();
        cursor_line = LINE_MAX - 1;
    }
}

int putc(int c)
{
    int offset;
    char *p;

    if (c == '\n') {
        incline();
        goto update_position;
    }

    if (cursor_column >= COLUMN_MAX)
        incline();

    // 2 bytes per character
    offset = 2 * (cursor_line * COLUMN_MAX + cursor_column);
    p = vga_buffer + offset;
    out_byte(p, c, GREEN_COLOR);
    cursor_column++;

update_position:
    offset = cursor_line * COLUMN_MAX + cursor_column;
    set_cursor(offset);
    return 1;
}

/*
    https://bochs.sourceforge.io/techspec/PORTS.LST

    彩色显示器
    内存范围：0xB8000 - 0XBFFFF，共32KB
    支持8页，每页 80列 x 25行
    每个字符255个属性，占两个字节，因此一页内容4000字节
    
    读取光标位置
    索引寄存器：0x03D4
               0x0E - 光标位置高8位
               0x0F - 光标位置低8位
    数据寄存器：0x03D5
*/

// 读取光标位置
int read_cursor(void)
{
    int low, high;

    outb(0x03d4, 0x0e);
    inb(0x03d5, &high);
    outb(0x03d4, 0x0f);
    inb(0x03d5, &low);
    
    return (high << 8) | low;
}

// 设置光标位置
void set_cursor(int position)
{
    outb(0x03d4, 0x0e);
    outb(0x03d5, position >> 8);
    outb(0x03d4, 0x0f);
    outb(0x03d5, position & 0xff);
}

int printf(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(print_buffer, sizeof(print_buffer), fmt, ap);
    va_end(ap);
    return 0;
}

void console_init(void)
{
    int pos;

    // 80 columns x 25 lines
    pos = read_cursor();
    cursor_line = pos / COLUMN_MAX;
    cursor_column = pos % COLUMN_MAX;
    incline();
}

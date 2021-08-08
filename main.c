// using gcc bulitins
#define va_list __builtin_va_list
#define va_start __builtin_va_start
#define va_end __builtin_va_end
#define va_arg __builtin_va_arg

extern void sti(void);
extern int printk(const char *fmt, ...);
extern int vsnprintk(char *str, int size, const char *fmt, va_list ap);
extern int kputs(char *str);
extern int kputc(int c);
extern int read_cursor(void);
extern void set_cursor(int position);
extern void hlt(void);

#define INT_MIN 0x80000000
#define INT_MAX 0x7FFFFFFF

#define LINE_MAX    25
#define COLUMN_MAX  80
#define PAGE_MAX    8

#define GREEN_COLOR 0x02

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

static void test_print(void)
{
    short *buffer;
    int ch = 'C';

    vga_buffer = (char *)0xb8000;
    *(short *)vga_buffer = ((GREEN_COLOR & 0xff) << 8) | (ch & 0xff);
}

int main()
{
    int pos;

    // 80 columns x 25 lines
    pos = read_cursor();
    cursor_line = pos / COLUMN_MAX;
    cursor_column = pos % COLUMN_MAX;

    printk("Hello, kern64!\n");
    // kputs("Hello, kern64!\n");
    // test_print();

    for (;;);
    return 0;
}

int printk(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vsnprintk(print_buffer, sizeof(print_buffer), fmt, ap);
    va_end(ap);
    return 0;
}

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
    if (f->to < f->stop)
        *f->to++ = c;
}

static void fmt_puts(struct fmt *f, char *s)
{
    for (; *s; s++)
        fmt_putc(f, *s);
}

// %c,%d,%x,%s,%p
int vsnprintk(char *str, int size, const char *fmt, va_list ap)
{
    int c;
    unsigned int u;
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
        case 'p':
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
            if (*fmt == 'p') {
                *--s = 'x';
                *--s = '0';
            }
            fmt_puts(&f, s);
            break;
        
        case 's':
            s = va_arg(ap, char *);
            fmt_puts(&f, s);
            break;
        
        default:
            fmt_putc(&f, *fmt);
            break;
        }
    }

    fmt_fini(&f);
    return kputs(str);
}

int kputs(char *str)
{
    char *p;

    for (p = str; *p; p++)
        kputc(*p);
    return (p - str);
}

static void outb(char *buffer, int ch, int color)
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

int kputc(int c)
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
    outb(p, c, GREEN_COLOR);
    cursor_column++;

update_position:
    offset = cursor_line * COLUMN_MAX + cursor_column;
    set_cursor(offset);
    return 1;
}
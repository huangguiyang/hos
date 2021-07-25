
typedef char *va_list;

#define __va_rounded_size(TYPE)  \
  (((sizeof (TYPE) + sizeof (int) - 1) / sizeof (int)) * sizeof (int))

#define va_start(AP, LASTARG) 						\
 (AP = ((char *) &(LASTARG) + __va_rounded_size (LASTARG)))

 void va_end (va_list);		/* do nothing */
#define va_end(AP)

#define va_arg(AP, TYPE)						\
 (AP += __va_rounded_size (TYPE),					\
  *((TYPE *) (AP - __va_rounded_size (TYPE))))

extern void sti(void);
extern int printf(const char *fmt, ...);
extern int vsnprintf(char *str, int size, const char *fmt, va_list ap);
extern int puts(char *str);
extern int putc(int c);
extern int read_cursor(void);
extern void set_cursor(int position);

#define INT_MIN 0x80000000
#define INT_MAX 0x7FFFFFFF

#define LINE_MAX    25
#define COLUMN_MAX  80

#define GREEN_COLOR 0x02

// Color VGA
static char *vga_buffer = (char *)0xb8000;

int cursor_line;
int cursor_column;
static char obuf[1024]; // print buffer

struct fmt {
    char *buf;
    char *to;       // current
    char *stop;
};

int main()
{
    int pos;

    // 80 columns x 25 lines
    pos = read_cursor();
    cursor_line = pos / COLUMN_MAX;
    cursor_column = pos % COLUMN_MAX;
    sti();

    printf("Hello, world!\nabc %x", 0xb0120);

    for (;;); // never return
    
    return 0;
}

int printf(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(obuf, sizeof(obuf), fmt, ap);
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
int vsnprintf(char *str, int size, const char *fmt, va_list ap)
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

int putc(int c)
{
    int offset;
    char *p;

    if (c == '\n') {
        cursor_line++;
        cursor_column = 0;
        goto update_position;
    }

    if (cursor_column >= COLUMN_MAX) {
        cursor_line++;
        cursor_column = 0;
    }

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

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

#define LINE_MAX    25
#define COLUMN_MAX  80

#define GREEN_COLOR 0x02

// Color VGA
static char *vga_buffer = (char *)0xb8000;

int cursor_line;
int cursor_column;
static char obuf[1024]; // print buffer

int main()
{
    int pos;

    // 80 columns x 25 lines
    pos = read_cursor();
    cursor_line = pos / COLUMN_MAX;
    cursor_column = pos % COLUMN_MAX;
    sti();

    puts("Hello, world!\nabc");

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

// %c,%d,%x,%s
int vsnprintf(char *str, int size, const char *fmt, va_list ap)
{
    int c;
    char *p;

    p = str;
    for (; *fmt; fmt++) {
        if (*fmt != '%')
            goto putchar;

        c = fmt[1];

        switch (c) {
        case 'c':
        case 'd':
            break;
        default:
            break;
        }

    putchar:
        if (p - str >= size - 1)
            break;
        *p = c;
        p++;
    }

    *p = 0;
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

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
extern void hlt(void);
extern void clear_screen(void);

extern void page_fault_handler(void);
extern void divide_error_handler(void);
extern void invalidate_tlb(void);

#define INT_MIN 0x80000000
#define INT_MAX 0x7FFFFFFF

#define LINE_MAX    25
#define COLUMN_MAX  80
#define PAGE_MAX    8

#define GREEN_COLOR 0x02

#define set_trap_gate(index, handler) \
    set_gate(idt + (index), 15, 0, (int)(handler))

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

// descriptor
struct desc {
    int a,b;
};
extern struct desc idt[256];
extern int page_dir[4];

static void set_gate(struct desc *p, int type, int dpl, int address)
{
    p->a = 0x00080000 | (address & 0xffff);
    p->b = (address & 0xffff0000) | (0x8000 + (dpl << 13) + (type << 8));
}

int main()
{
    int pos;

    // 80 columns x 25 lines
    pos = read_cursor();
    cursor_line = pos / COLUMN_MAX;
    cursor_column = pos % COLUMN_MAX;

    // Intel Manual Vol 3 - 6.3.1 External Interupts
    set_trap_gate(0, divide_error_handler);
    set_trap_gate(14, page_fault_handler);
    sti();

    printf("Hello, world!\npage_dir:%p\n", &page_dir);

    int *p = (int *)(1 *1024 * 1024 + 1024 * 4 - 2);
    *p = 0x12345678;
    // pos = *p;
    printf("p=%d\n", *p);

    for (;;); // never return
    
    return 0;
}

int printf(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(print_buffer, sizeof(print_buffer), fmt, ap);
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
    return puts(str);
}

int puts(char *str)
{
    char *p;

    for (p = str; *p; p++)
        putc(*p);
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
    outb(p, c, GREEN_COLOR);
    cursor_column++;

update_position:
    offset = cursor_line * COLUMN_MAX + cursor_column;
    set_cursor(offset);
    return 1;
}

void do_divide_error(int errcode, int address)
{
    printf("divide error: %d, 0x%x\n", errcode, address);
}

void do_page_fault(int errcode, int address)
{
    int i, j;
    int *p;

    printf("page fault: %d, 0x%x\n", errcode, address);

    i = (address >> 22) & 0x3ff;    // page dir index
    j = (address >> 12) & 0x3ff;    // page table index

    p = (int *) (page_dir[i] & 0xFFFFF000); // 高20位是页表地址
    p[j] = (j << 12) | 3;
}

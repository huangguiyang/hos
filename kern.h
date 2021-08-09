// using gcc bulitins
#define va_list __builtin_va_list
#define va_start __builtin_va_start
#define va_end __builtin_va_end
#define va_arg __builtin_va_arg

extern void sti(void);
extern void hlt(void);
extern int read_cursor(void);
extern void set_cursor(int position);

// I/O PORTS
extern void inb(int port, int *byte);
extern void inw(int port, int *word);
extern void indw(int port, int *dword);
extern void outb(int port, int byte);
extern void outw(int port, int word);
extern void outdw(int port, int dword);

struct cpuinfo {
    int eax,ebx,ecx,edx;
};
extern void cpuid(struct cpuinfo *info);

extern void tty_init(void);
extern int printf(const char *fmt, ...);
extern int vsnprintf(char *str, int size, const char *fmt, va_list ap);
extern int puts(char *str);
extern int putc(int c);
extern void *memset(void *p, int c, unsigned long len);

extern void lscpu(void);

extern void apic_init(void);
extern void mp_init(void);
extern void task_init(void);
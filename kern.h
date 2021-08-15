// using gcc bulitins
#define va_list __builtin_va_list
#define va_start __builtin_va_start
#define va_end __builtin_va_end
#define va_arg __builtin_va_arg

#define MIN(a, b)   ((a) <= (b) ? (a) : (b))
#define MAX(a, b)   ((a) >= (b) ? (a) : (b))
#define NELMS(a)    (sizeof(a)/sizeof((a)[0]))

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
extern void *memcpy(void *dst, void *src, unsigned long len);

// IPI broadcast mode
#define NO_BROCAST          0
#define SELF                1
#define ALL_INCLUDING_SELF  2
#define ALL_EXCLUDING_SELF  3

extern void apic_init(void);
extern void mp_init(void);
extern void task_init(void);

extern void send_init_ipi(int mode, int asrt);
extern void send_startup_ipi(int mode, int vector);

extern void rdmsr(int addr, int *low, int *high);
extern void wrmsr(int addr, int low, int high);

#define IA32_MTRRCAP                0xfe
#define IA32_MTRR_DEF_TYPE          0x2ff
#define IA32_MTRR_FIX64K_00000      0x250
#define IA32_MTRR_FIX16K_80000      0x258
#define IA32_MTRR_FIX16K_A0000      0x259
#define IA32_MTRR_FIX4K_C0000       0x268
#define IA32_MTRR_FIX4K_C8000       0x269
#define IA32_MTRR_FIX4K_D0000       0x26a
#define IA32_MTRR_FIX4K_D8000       0x26b
#define IA32_MTRR_FIX4K_E0000       0x26c
#define IA32_MTRR_FIX4K_E8000       0x26d
#define IA32_MTRR_FIX4K_F0000       0x26e
#define IA32_MTRR_FIX4K_F8000       0x26f

#define IA32_MTRR_PHYSBASE0         0x200
#define IA32_MTRR_PHYSMASK0         0x201
#define IA32_MTRR_PHYSBASE1         0x202
#define IA32_MTRR_PHYSMASK1         0x203
#define IA32_MTRR_PHYSBASE2         0x204
#define IA32_MTRR_PHYSMASK2         0x205
#define IA32_MTRR_PHYSBASE3         0x206
#define IA32_MTRR_PHYSMASK3         0x207
#define IA32_MTRR_PHYSBASE4         0x208
#define IA32_MTRR_PHYSMASK4         0x209
#define IA32_MTRR_PHYSBASE5         0x20a
#define IA32_MTRR_PHYSMASK5         0x20b
#define IA32_MTRR_PHYSBASE6         0x20c
#define IA32_MTRR_PHYSMASK6         0x20d
#define IA32_MTRR_PHYSBASE7         0x20e
#define IA32_MTRR_PHYSMASK7         0x20f
#define IA32_MTRR_PHYSBASE8         0x210
#define IA32_MTRR_PHYSMASK8         0x211
#define IA32_MTRR_PHYSBASE9         0x212
#define IA32_MTRR_PHYSMASK9         0x213

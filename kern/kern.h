// using gcc bulitins
#define va_list __builtin_va_list
#define va_start __builtin_va_start
#define va_end __builtin_va_end
#define va_arg __builtin_va_arg

#define NULL ((void *)0)
#define MIN(a, b)   ((a) <= (b) ? (a) : (b))
#define MAX(a, b)   ((a) >= (b) ? (a) : (b))
#define NELMS(a)    (sizeof(a)/sizeof((a)[0]))

extern void sti(void);
extern void hlt(void);
extern void pause(void);
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
extern int memcmp(void *a, void *b, unsigned long len);

// IPI destination shorthand
#define NO_SHORTHAND        0
#define SELF                1
#define ALL_INCLUDING_SELF  2
#define ALL_EXCLUDING_SELF  3

extern void rdmsr(int addr, int *low, int *high);
extern void wrmsr(int addr, int low, int high);
extern void set_cr3(void *addr);

/*
 is it bootstrap processor?
 通过读取 IA32_APIC_BASE MSR BSP 标志位(bit 8)来确定
 */
extern int is_bsp(void);

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

#define IA32_APIC_BASE              0x1b

// RSDP (Root System Description Pointer) structure
struct rsdp {
    char signature[8];              // "RSD PTR "
    unsigned char checksum;
    char oem_id[6];
    unsigned char revision;
    unsigned int rsdt_addr;         // 32-bit physical address

    // version 2
    int length;
    long xsdt_addr;;
    char exchecksum;
    char reserved[3];
};

// RSDT (Root System Description Table) structure
struct acpi_sdt_hdr {
    char signature[4];
    unsigned int length;
    unsigned char revision;
    unsigned char checksum;
    char oem_id[6];
    char oem_table_id[8];
    unsigned int oem_revision;
    unsigned int creator_id;
    unsigned int creator_revision;
};

// MADT (Multiple APIC Description Table)
struct madt_hdr {
    struct acpi_sdt_hdr hdr;
    unsigned int local_apic_addr;
    unsigned int flags;
};

struct madt_entry_hdr {
    unsigned char type;
    unsigned char length;
};

#define SIG_MAGIC(a,b,c,d)  ((d << 24 ) | (c << 16) | (b << 8) | a)
#define APIC_MAGIC  SIG_MAGIC('A','P','I','C')

/*
所有逻辑处理器的默认 LOCAL APIC 地址都是一样的 (0xFEE00000)
可以通过修改 IA32_APIC_BASE MSR 来修改这个地址
*/ 

#define LOCAL_APIC_ADDR                   0xFEE00000
#define LOCAL_APIC_ID_REG(base)           ((unsigned int)(base) + 0x20)
#define LOCAL_APIC_VERSION_REG(base)      ((unsigned int)(base) + 0x30)
#define LOCAL_APIC_ICR_LOW32(base)        ((unsigned int)(base) + 0x300)
#define LOCAL_APIC_ICR_HIGH32(base)       ((unsigned int)(base) + 0x310)

struct cpu {
    unsigned char acpi_procssor_id;
    unsigned char apic_id;
    unsigned int flags;
};

// 4k paging flags
#define PAGING_P        (1 << 0)
#define PAGING_W        (1 << 1)
#define PAGING_USER     (1 << 2)
#define PAGING_PWT      (1 << 3)
#define PAGING_PCD      (1 << 4)
#define PAGING_ACCESSED (1 << 5)
#define PAGING_DIRTY    (1 << 6)
#define PAGING_PAT      (1 << 7)
#define PAGING_GLOBAL   (1 << 8)
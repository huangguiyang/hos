#include "kern.h"

static int maxphyaddr = 36;
static int maxlineaddr = 48;
static int fix_mttrs[] = {
    IA32_MTRR_FIX64K_00000,
    IA32_MTRR_FIX16K_80000,
    IA32_MTRR_FIX16K_A0000,
    IA32_MTRR_FIX4K_C0000,
    IA32_MTRR_FIX4K_C8000,
    IA32_MTRR_FIX4K_D0000,
    IA32_MTRR_FIX4K_D8000,
    IA32_MTRR_FIX4K_E0000,
    IA32_MTRR_FIX4K_E8000,
    IA32_MTRR_FIX4K_F0000,
    IA32_MTRR_FIX4K_F8000,
};

static int physbase_mtrrs[] = {
    IA32_MTRR_PHYSBASE0,
    IA32_MTRR_PHYSBASE1,
    IA32_MTRR_PHYSBASE2,
    IA32_MTRR_PHYSBASE3,
    IA32_MTRR_PHYSBASE4,
    IA32_MTRR_PHYSBASE5,
    IA32_MTRR_PHYSBASE6,
    IA32_MTRR_PHYSBASE7,
    IA32_MTRR_PHYSBASE8,
    IA32_MTRR_PHYSBASE9,
};

static int physmask_mtrrs[] = {
    IA32_MTRR_PHYSMASK0,
    IA32_MTRR_PHYSMASK1,
    IA32_MTRR_PHYSMASK2,
    IA32_MTRR_PHYSMASK3,
    IA32_MTRR_PHYSMASK4,
    IA32_MTRR_PHYSMASK5,
    IA32_MTRR_PHYSMASK6,
    IA32_MTRR_PHYSMASK7,
    IA32_MTRR_PHYSMASK8,
    IA32_MTRR_PHYSMASK9,
};

// 4K aligned entry
static int start_ip;
#define ICR_LOW32   0xFEE00300
#define ICR_HIGH32  0xFEE00310

static void lscpu(void);
static void lsmtrr(void);
static void lstopo(void);

int main()
{
    struct cpuinfo info;

    tty_init();
    
    printf("Hello, kern64!\n");

    info.eax = 0x80000008;
    cpuid(&info);
    maxphyaddr = info.eax & 0xff;
    maxlineaddr = (info.eax >> 8) & 0xff;
    printf("MAXPHYADDR=%d, MAXLINEADDR=%d\n", maxphyaddr, maxlineaddr);

    lscpu();
    lsmtrr();
    lstopo();
    struct rsdp *p = search_rsdp();
    if (p) {
        printf("RSDP = %p, ver = %d, OEM = ", p, p->revision);
        for (int i = 0; i < 6; i++)
            putc(p->oemid[i]);
        printf(", RSDT = %p\n", p->rsdt_addr);
    }

    for (;;);
    return 0;
}

static void lscpu(void)
{
    struct cpuinfo info;
    int c;
    char vendor[13];

    info.eax = 0;
    cpuid(&info);
    c = info.eax;
    printf("CPUID MAX: %d\n", c);

    vendor[0] = info.ebx & 0xff;
    vendor[1] = (info.ebx >> 8) & 0xff;
    vendor[2] = (info.ebx >> 16) & 0xff;
    vendor[3] = (info.ebx >> 24) & 0xff;
    vendor[4] = info.edx & 0xff;
    vendor[5] = (info.edx >> 8) & 0xff;
    vendor[6] = (info.edx >> 16) & 0xff;
    vendor[7] = (info.edx >> 24) & 0xff;
    vendor[8] = info.ecx & 0xff;
    vendor[9] = (info.ecx >> 8) & 0xff;
    vendor[10] = (info.ecx >> 16) & 0xff;
    vendor[11] = (info.ecx >> 24) & 0xff;
    vendor[12] = 0;

    printf("Vendor: %s\n", vendor);

    // 是否支持硬件多线程 (Hardware Multi-Threading)
    info.eax = 1;
    cpuid(&info);
    c = (info.edx >> 28) & 1;
    printf("HMT supported: %d\n", c);
    
    c = (info.ebx >> 16) & 0xff;
    printf("Logical Processors: %d\n", c);
    
    info.eax = 4;
    info.ecx = 0;
    cpuid(&info);
    c = 1 + ((info.eax >> 26) & 0x3f);
    printf("Cores: %d\n", c);
}

static void lsmtrr(void)
{
    struct cpuinfo info;
    int c, i;
    unsigned int high, low;
    int vcnt, fix, wc, smrr;
    int dtype, fe, e;
    unsigned long base, mask;
    int type, valid;

    info.eax = 1;
    cpuid(&info);
    c = (info.edx >> 12) & 1;
    if (c == 0) {
        printf("MTRR not supported.\n");
        return;
    }

    rdmsr(IA32_MTRRCAP, &low, &high);
    vcnt = low & 0x0f;
    fix = (low >> 8) & 1;
    wc = (low >> 10) & 1;
    smrr = (low >> 11) & 1;
    printf("VCNT=%d,FIX=%d,WC=%d,SMRR=%d\n", vcnt, fix, wc, smrr);

    rdmsr(IA32_MTRR_DEF_TYPE, &low, &high);
    dtype = low & 0x0f;
    fe = (low >> 10) & 1;
    e = (low >> 11) & 1;
    printf("default-type=%d,FE=%d,E=%d\n", dtype, fe, e);

    if (fix && fe) {
        // dump fix mtrr
        c = NELMS(fix_mttrs);
        for (i = 0; i < c; i++) {
            rdmsr(fix_mttrs[i], &low, &high);
            base = ((long)high << 32) | low;
            printf("FIX[%d]: %lx, ", i, base);
        }
        printf("\n");
    }

    c = MIN(vcnt, NELMS(physbase_mtrrs));
    for (i = 0; i < c; i++) {
        rdmsr(physbase_mtrrs[i], &low, &high);
        base = ((long)high << 32) | low;
        printf("BASE[%d]: %lx, ", i, base);
        rdmsr(physmask_mtrrs[i], &low, &high);
        mask = ((long)high << 32) | low;
        printf("MASK[%d]: %lx\n", i, mask);
    }
}

static void lstopo(void)
{
    struct cpuinfo info;
    int type = 1;
    int s = 0;

    while (type) {
        info.eax = 0x0b;
        info.ecx = s;
        cpuid(&info);
        type = (info.ecx >> 8) & 0xff;
        s++;
    }
    s = info.ecx & 0xff;
    printf("MAX VALID LEVEL: %d\n", s);
}

static struct rsdp *search_rsdp(void)
{
    char *beg = 0xe0000;
    char *end = 0xfffff;
    char sig[] = "RSD PTR ";
    char c, *p;

    for (; beg < end; beg += 16) {
        if (!memcmp(beg, sig, 8)) {
            // verify checksum
            c = 0;
            for (p = beg; p < beg + 20; p++)
                c += *p;
            if (c == 0)
                return (struct rsdp *)beg;
        }
    }
    return 0;
}

/*
MultiProcessor Initialization
*/

void mp_init(void)
{
    send_init_ipi(ALL_EXCLUDING_SELF, 1);

    send_init_ipi(ALL_INCLUDING_SELF, 0);

    send_startup_ipi(ALL_EXCLUDING_SELF, start_ip >> 12);
    send_startup_ipi(ALL_EXCLUDING_SELF, start_ip >> 12);
}

void send_init_ipi(int mode, int asrt)
{
    int c;
    
    // INIT, edge, assert
    c = (mode << 18) | (asrt << 14) | (5 << 8);

    *((int *)ICR_HIGH32) = 0;
    *((int *)ICR_LOW32) = c;
}

void send_startup_ipi(int mode, int vector)
{
    int c;

    // STARTUP, edge
    c = (mode << 18) | (6 << 8) | (vector & 0xff);

    *((int *)ICR_HIGH32) = 0;
    *((int *)ICR_LOW32) = c;
}

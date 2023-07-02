#include "kern.h"

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

void ls_cpu(void)
{
    struct cpuid info;
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

void ls_mtrr(void)
{
    struct cpuid info;
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

void ls_topology(void)
{
    struct cpuid info;
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

void delay_ms(int ms)
{
    int k1, k2;

    k1 = 123;
    k2 = 456;

    for (int i = 0; i < ms; i++)
        for (long j = 0; j < (1L<<14); j++)
            k2 = k1 + k2;
}

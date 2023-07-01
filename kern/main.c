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
static int start_ip = 0x1000;   // kern16 start address
static struct cpu cpus[8];
static int ncpu;

static void *page_dir_root = (void *)0x8000;    // 32K
#define DIRTY_MAP_ADDR  0x30000         // 192K
#define DIRTY_MAP_SIZE  0x20000         // 128K

static void lscpu(void);
static void lsmtrr(void);
static void lstopo(void);
static void lsrsdp(void);
static struct rsdp *search_rsdp(void);
static void print_rsdp(struct rsdp *p);
static struct acpi_sdt_hdr *search_rsdt(struct rsdp *p);
static void print_sdt(struct acpi_sdt_hdr *p);
static int verify_sdt_checksum(struct acpi_sdt_hdr *p);
static struct madt_hdr *search_sdt(struct acpi_sdt_hdr *rsdt, int magic);
static struct madt_hdr *search_madt(void);
static void paging_init(void);
static void interrupts_init(void);
static void mp_init(void *cur_lapic_base);
static void *alloc_page(void);
static void *alloc_fixed_page(void *p);
static void *free_page(void *p);
static void mmap(void *p, int flags);
static void spin_wait(int ms);
static int is_bsp(void);
static void enable_apic(void);
static void disable_apic(void);
static void *get_lapic_base_addr(void);
static void set_lapic_base_addr(void *p);
static unsigned int read_lapic_reg(void *base, int offset);
static void write_lapic_reg(void *base, int offset, int value);
static unsigned int get_lapic_id(void *base);

int main()
{
    tty_init();
    paging_init();
    
    printf("Hello, kern64! %s\n", is_bsp() ? "I'm the BSP" : "I'm an AP");

    unsigned int low, high;
    unsigned long v;

    rdmsr(IA32_APIC_BASE, &low, &high);
    v = ((unsigned long)high) << 32 | low;
    printf("IA32_APIC_BASE: %lx\n", v);

    // struct cpuinfo info;
    // info.eax = 0x80000008;
    // cpuid(&info);
    // maxphyaddr = info.eax & 0xff;
    // maxlineaddr = (info.eax >> 8) & 0xff;
    // printf("MAXPHYADDR=%d, MAXLINEADDR=%d\n", maxphyaddr, maxlineaddr);

    // lscpu();
    // lsmtrr();
    // lstopo();
    // lsrsdp();
    struct madt_hdr *madt = search_madt();
    if (madt) {
        printf("MADT=%p, local_apic_addr=%p, flags=%d\n", madt, (void *)madt->local_apic_addr, madt->flags);
        if (madt->local_apic_addr != LAPIC_BASE_ADDR)
            printf("unexpected local apic address: %p\n", (void *)madt->local_apic_addr);
        unsigned int e = madt + 1;
        while (e < (unsigned int)madt + madt->hdr.length) {
            struct madt_entry_hdr *ep = e;
            // printf("entry type=%d, length=%d\n", (int)ep->type, (int)ep->length);
            if (ep->type == 0) {
                char *addr = ep + 1;
                unsigned char acpi_pid = addr[0];
                unsigned char apic_id = addr[1];
                unsigned int flags = *(int *)(addr + 2);
                if (ncpu < NELMS(cpus)) {
                    cpus[ncpu].acpi_procssor_id = acpi_pid;
                    cpus[ncpu].apic_id = apic_id;
                    cpus[ncpu].flags = flags;
                    ncpu++;
                } else {
                    printf("too many cpus\n");
                }
                printf("\tACPI PID=%d, APIC ID=%d, flags=%d\n", (int)acpi_pid, (int)apic_id, flags);
            }
            e += ep->length;
        }
    }
    printf("%d APIC(s) found.\n", ncpu);
    
    void *p = get_lapic_base_addr();
    mmap(p, PAGING_W | PAGING_PCD);
    int local_apic_id = get_lapic_id(p);
    int local_apic_ver = read_lapic_reg(p, LAPIC_VERSION_REG);
    printf("Current APIC ID=%d, ver=0x%x\n", local_apic_id, local_apic_ver);

    mp_init(p);

    for (;;) pause();
    return 0;
}

static int is_bsp(void)
{
    int low = 0, high = 0;
    rdmsr(IA32_APIC_BASE, &low, &high);
    return low & (1 << 8); // BSP flag is at bit8
}

static void enable_apic(void)
{
    unsigned int low = 0, high = 0;

    rdmsr(IA32_APIC_BASE, &low, &high);

    low |= 1 << 11;
    wrmsr(IA32_APIC_BASE, low, high);
}

static void disable_apic(void)
{
    unsigned int low = 0, high = 0;

    rdmsr(IA32_APIC_BASE, &low, &high);

    low &= ~(1 << 11);
    wrmsr(IA32_APIC_BASE, low, high);
}

static void *get_lapic_base_addr(void)
{
    unsigned int low = 0;

    rdmsr(IA32_APIC_BASE, &low, NULL);

    return (void *)(low & ~0xFFF);
}

static void set_lapic_base_addr(void *p)
{
    unsigned int low = 0, high = 0;

    rdmsr(IA32_APIC_BASE, &low, &high);
    low = (low & 0xFFF) | ((unsigned int)p & ~0xFFF);

    wrmsr(IA32_APIC_BASE, low, high);
}

// !!! MUST be unsigned!

static unsigned int read_lapic_reg(void *base, int offset)
{
    return *(int *)((unsigned int)base + offset);
}

static void write_lapic_reg(void *base, int offset, int value)
{
    *(int *)((unsigned int)base + offset) = value;
}

static unsigned int get_lapic_id(void *base)
{
    return read_lapic_reg(base, LAPIC_ID_REG) >> 24;
}

void ap_main()
{
    printf("\nHello, kern64! %s\n", is_bsp() ? "fatal error" : "I'm an AP.");

    unsigned int low, high;
    unsigned long v;

    low = high = 0;

    rdmsr(IA32_APIC_BASE, &low, &high);
    v = ((unsigned long)high) << 32 | low;
    printf("IA32_APIC_BASE: %lx\n", v);

    void *p = get_lapic_base_addr();
    int local_apic_id = get_lapic_id(p);
    int local_apic_ver = read_lapic_reg(p, LAPIC_VERSION_REG);
    printf("Current APIC ID=%d, ver=0x%x\n", local_apic_id, local_apic_ver);

    /*
        QEMU 似乎是不支持重新映射 Local APIC Address

        https://lists.nongnu.org/archive/html/qemu-devel/2012-05/msg03373.html

        [Intel Manual]
        For P6 family, Pentium 4, and Intel Xeon processors, the APIC handles 
         all memory accesses to addresses within the 4-KByte APIC register space 
         internally and no external bus cycles are produced.

        [Conclusion]
        We don't need to change the base address, because each processor
         will only write to its own APIC even if all of them use the same base address.

    */

    // disable_apic();
    // void *p1 = alloc_page();
    // mmap(p1, PAGING_W | PAGING_PCD);
    // printf("alloc page: %p\n", p1);
    // set_lapic_base_addr(p1);
    // enable_apic();

    // p = get_lapic_base_addr();
    // printf("p=%p\n", p);
    // local_apic_id = get_lapic_id(p);
    // local_apic_ver = read_lapic_reg(p, LAPIC_VERSION_REG);
    // printf("*Current APIC ID=%d, ver=0x%x\n", local_apic_id, local_apic_ver);

    for (;;) pause();
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

static void lsrsdp(void)
{
    struct rsdp *rsdp = search_rsdp();
    if (rsdp) {
        print_rsdp(rsdp);
        struct acpi_sdt_hdr *rsdt = search_rsdt(rsdp);
        if (rsdt) {
            print_sdt(rsdt);
            int nsdt = (rsdt->length - sizeof(*rsdt)) / 4;
            unsigned int *psdt = rsdt + 1;
            for (int i = 0; i < nsdt; i++) {
                struct acpi_sdt_hdr *sdt = (struct acpi_sdt_hdr *)psdt[i];
                if (verify_sdt_checksum(sdt) == 0) {
                    printf("[%d] ", i);
                    print_sdt(sdt);
                }
            }
        }
    }
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

static void print_rsdp(struct rsdp *p)
{
    if (p == NULL) return;

    printf("RSDP=%p, ver=%d, OEM=", p, p->revision);
    for (int i = 0; i < 6; i++)
        putc(p->oem_id[i]);
    printf(", RSDT=%p\n", p->rsdt_addr);
}

// checksum = 0 is ok
static int verify_sdt_checksum(struct acpi_sdt_hdr *p)
{
    unsigned char sum = 0;
    for (int i = 0; i < p->length; i++)
        sum += ((char *)p)[i];
    return sum;
}

static struct acpi_sdt_hdr *search_rsdt(struct rsdp *p)
{
    if (p == NULL) return NULL;

    struct acpi_sdt_hdr *hdr = p->rsdt_addr;
    return verify_sdt_checksum(hdr) == 0 ? hdr : NULL;
}

static void print_sdt(struct acpi_sdt_hdr *p)
{
    if (p == NULL) return;

    for (int i = 0; i < 4; i++)
        putc(p->signature[i]);
    printf("=%p, OEM=", p);
    for (int i = 0; i < 6; i++)
        putc(p->oem_id[i]);
    printf("\n");
}

static struct madt_hdr *search_sdt(struct acpi_sdt_hdr *rsdt, int magic)
{
    if (rsdt == NULL)
        return NULL;

    int nsdt = (rsdt->length - sizeof(*rsdt)) / 4;
    unsigned int *psdt = rsdt + 1;
    for (int i = 0; i < nsdt; i++) {
        struct acpi_sdt_hdr *sdt = (struct acpi_sdt_hdr *)psdt[i];
        mmap(sdt, 0);
        if (verify_sdt_checksum(sdt) == 0) {
            if (*(int *)sdt->signature == magic)
                return sdt;
        }
    }
    return NULL;
}

static struct madt_hdr *search_madt(void)
{
    struct rsdp *rsdp = search_rsdp();
    if (rsdp) {
        mmap(rsdp->rsdt_addr, 0);
        struct acpi_sdt_hdr *rsdt = search_rsdt(rsdp);
        return search_sdt(rsdt, APIC_MAGIC);
    }

    return NULL;
}

/*
    IPI Message
*/

static void send_init_ipi_to_apic(void *lapic_base, int apic_id)
{
    write_lapic_reg(lapic_base, LAPIC_ICR_HIGH32, (apic_id & 0xFF) << ICR_DESTINATION_SHIFT);
    write_lapic_reg(lapic_base, LAPIC_ICR_LOW32, 
                    ICR_INIT | ICR_PHYSICAL | ICR_DEASSERT | ICR_EDGE | ICR_NO_SHORTHAND);
}

static void send_startup_ipi_to_apic(void *lapic_base, int apic_id, int vector)
{
    write_lapic_reg(lapic_base, LAPIC_ICR_HIGH32, (apic_id & 0xFF) << ICR_DESTINATION_SHIFT);
    write_lapic_reg(lapic_base, LAPIC_ICR_LOW32,  (vector & 0xFF) |
                    ICR_STARTUP | ICR_PHYSICAL | ICR_ASSERT | ICR_EDGE | ICR_NO_SHORTHAND);
}

/*
    Send INIT-SIPI-SIPI sequence
*/

static void mp_init(void *lapic_base)
{
    printf("Initialize other cores...\n");
    send_init_ipi_to_apic(lapic_base, 1);
    while (read_lapic_reg(lapic_base, LAPIC_ICR_LOW32) & ICR_PENDING)
        ;/* wait */
    spin_wait(10);
    
    send_startup_ipi_to_apic(lapic_base, 1, start_ip >> 12);
    while (read_lapic_reg(lapic_base, LAPIC_ICR_LOW32) & ICR_PENDING)
        ;/* wait */
    spin_wait(200);
    
    send_startup_ipi_to_apic(lapic_base, 1, start_ip >> 12);
    while (read_lapic_reg(lapic_base, LAPIC_ICR_LOW32) & ICR_PENDING)
        ;/* wait */
    spin_wait(200);
}

static void *free_page(void *p)
{
    int *dirty_map_addr = (int *)DIRTY_MAP_ADDR;
    unsigned int u = p;
    int i = u >> 17;
    int b = (u >> 12) & 31;
    
    dirty_map_addr[i] &= ~(1 << b);
}

static void *alloc_page(void)
{
    int *dirty_map_addr = (int *)DIRTY_MAP_ADDR;
    int b = 0;

    for (int i = 0; i < 4096/sizeof(int); i++) {
        unsigned int k = dirty_map_addr[i];
        for (int j = 0; j < 8 * sizeof(int); j++) {
            if (k & 1) {
                b++;
                k >>= 1;
                continue;
            } else {
                dirty_map_addr[i] |= 1 << j;
                return b << 12L;
            }
        }
    }

    return NULL;
}

static void *alloc_fixed_page(void *p)
{
    int *dirty_map_addr = (int *)DIRTY_MAP_ADDR;
    unsigned int u = p;
    int i = u >> 17;
    int b = (u >> 12) & 31;
    
    dirty_map_addr[i] |= 1 << b;

    return (long)p & ~4095;
}

static void *alloc_page_for_dir(void)
{
    void *p = alloc_page();
    for (int i = 0; i < 4096/8; i++)
        ((unsigned long *)p)[i] = 0;
    return p;
}

static void paging_init(void)
{
    //TODO:根据实际内存大小
    // 先按照4GB
    int *dirty_map_addr = (int *)DIRTY_MAP_ADDR;
    int n = 0x100000 / (4096 * sizeof(int) * 8);
    //1MB以内全部标记
    for (int i = 0; i < DIRTY_MAP_SIZE/sizeof(int); i++)
        dirty_map_addr[i] = i < n ? 0xFFFFFFFF : 0;
}

static void mmap(void *p, int flags)
{
    unsigned long u = p;
    unsigned long *d1, *d2, *d3, *d4;
    int i;
    unsigned long v;

    d1 = page_dir_root;
    i = (u >> 39) & 511;
    v = d1[i];

    if ((v & 1) == 0) {
        d2 = alloc_page_for_dir();
        printf("alloc page d2\n");
        d1[i] = (unsigned long)d2 | PAGING_W | PAGING_P;
    } else {
        v = (v << 16) >> 16;
        d2 = (v >> 12) << 12;
    }

    i = (u >> 30) & 511;
    v = d2[i];
    if ((v & 1) == 0) {
        d3 = alloc_page_for_dir();
        printf("alloc page d3\n");
        d2[i] = (unsigned long)d3 | PAGING_W | PAGING_P;
    } else {
        v = (v << 16) >> 16;
        d3 = (v >> 12) << 12;
    }

    i = (u >> 21) & 511;
    v= d3[i];
    if ((v & 1) == 0) {
        d4 = alloc_page_for_dir();
        printf("alloc page d4\n");
        d3[i] = (unsigned long)d4 | PAGING_W | PAGING_P;
    } else {
        v = (v << 16) >> 16;
        d4 = (v >> 12) << 12;
    }

    i = (u >> 12) & 511;
    v = d4[i];
    if ((v & 1) == 0) {
        void *p2 = alloc_fixed_page(p);
        d4[i] = (unsigned long)p2 | flags | PAGING_P;
        printf("mapped for %p\n", p);
    } else {
        d4[i] |= flags | PAGING_P;
        printf("already mapped for %p\n", p);
    }
}

static void interrupts_init(void)
{

}

static void spin_wait(int ms)
{
    int k1, k2;

    k1 = 123;
    k2 = 456;

    for (int i = 0; i < ms; i++)
        for (long j = 0; j < (1L<<20); j++)
            k2 = k1 + k2;
}
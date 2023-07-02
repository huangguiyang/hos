#include "kern.h"

struct lapic g_lapic[MAX_LAPIC];
uint g_lapic_num;

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

int is_bsp(void)
{
    int low = 0, high = 0;
    rdmsr(IA32_APIC_BASE, &low, &high);
    return low & (1 << 8); // BSP flag is at bit8
}

void enable_apic(void)
{
    unsigned int low = 0, high = 0;

    rdmsr(IA32_APIC_BASE, &low, &high);

    low |= 1 << 11;
    wrmsr(IA32_APIC_BASE, low, high);
}

void disable_apic(void)
{
    unsigned int low = 0, high = 0;

    rdmsr(IA32_APIC_BASE, &low, &high);

    low &= ~(1 << 11);
    wrmsr(IA32_APIC_BASE, low, high);
}

void *get_lapic_base_addr(void)
{
    unsigned int low = 0;

    rdmsr(IA32_APIC_BASE, &low, NULL);

    return (void *)(low & ~0xFFF);
}

// NOT supported by almost all virtual vms
static void set_lapic_base_addr(void *p)
{
    unsigned int low = 0, high = 0;

    rdmsr(IA32_APIC_BASE, &low, &high);
    low = (low & 0xFFF) | ((unsigned int)p & ~0xFFF);

    wrmsr(IA32_APIC_BASE, low, high);
}

// !!! MUST be unsigned!

int read_lapic_reg(void *base, int offset)
{
    return *(int *)((uint)base + offset);
}

void write_lapic_reg(void *base, int offset, int value)
{
    *(int *)((uint)base + offset) = value;
}

int get_lapic_id(void *base)
{
    return ((uint)read_lapic_reg(base, LAPIC_ID_REG)) >> 24;
}

void apic_init(void)
{
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
                if (g_lapic_num < NELMS(g_lapic)) {
                    g_lapic[g_lapic_num].acpi_procssor_id = acpi_pid;
                    g_lapic[g_lapic_num].apic_id = apic_id;
                    g_lapic[g_lapic_num].flags = flags;
                    g_lapic_num++;
                } else {
                    printf("too many cpus\n");
                }
                printf("\tACPI PID=%d, APIC ID=%d, flags=%d\n", (int)acpi_pid, (int)apic_id, flags);
            }
            e += ep->length;
        }
    }
    printf("%d APIC(s) found.\n", g_lapic_num);
}

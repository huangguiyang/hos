#include "kern.h"

int main()
{
    console_init();
    mm_init();
    apic_init();

    // struct cpuid info;
    // info.eax = 0x80000008;
    // cpuid(&info);
    // int maxphyaddr = info.eax & 0xff;
    // int maxlineaddr = (info.eax >> 8) & 0xff;
    // printf("MAXPHYADDR=%d, MAXLINEADDR=%d\n", maxphyaddr, maxlineaddr);

    // ls_cpu();
    // ls_mtrr();
    // ls_topology();

    unsigned int low, high;
    unsigned long v;
    rdmsr(IA32_APIC_BASE, &low, &high);
    v = ((unsigned long)high) << 32 | low;

    void *p = get_lapic_base_addr();
    mmap(p, PAGING_W | PAGING_PCD);
    int local_apic_id = get_lapic_id(p);
    int local_apic_ver = read_lapic_reg(p, LAPIC_VERSION_REG);

    printf("Hello, kern64! %s %d (APIC_MSR=%lx, APIC_VER=0x%x)\n", 
            is_bsp() ? "I'm CPU" : "ERROR", local_apic_id, v, local_apic_ver);

    smp_init();

    for (;;) pause();
    return 0;
}

int ap_main()
{
    unsigned int low, high;
    unsigned long v;

    low = high = 0;
    rdmsr(IA32_APIC_BASE, &low, &high);
    v = ((unsigned long)high) << 32 | low;

    void *p = get_lapic_base_addr();
    int local_apic_id = get_lapic_id(p);
    int local_apic_ver = read_lapic_reg(p, LAPIC_VERSION_REG);

    printf("Hello, kern64! %s %d (APIC_MSR=%lx, APIC_VER=0x%x)\n", 
            is_bsp() ? "ERROR" : "I'm CPU", local_apic_id, v, local_apic_ver);

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


        实测：
        1.QEMU 可以修改地址，但获取值错误。
        2.VirtualBox 修改后，重新获取地址仍然不变，也就是不支持修改。
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

    g_lapic_ative_num++;

    for (;;) pause();
    return 0;
}

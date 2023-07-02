#include "kern.h"

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

void smp_init(void)
{
    if (g_lapic_num < 2) return;

    void *base = get_lapic_base_addr();

    // Send INIT-SIPI-SIPI sequence
    printf("Bring up APs...\n");
    send_init_ipi_to_apic(base, 1);
    while (read_lapic_reg(base, LAPIC_ICR_LOW32) & ICR_PENDING)
        ;/* wait */
    spin_wait(10);
    
    send_startup_ipi_to_apic(base, 1, AP_STARTUP_IP >> 12);
    while (read_lapic_reg(base, LAPIC_ICR_LOW32) & ICR_PENDING)
        ;/* wait */
    spin_wait(200);
    
    send_startup_ipi_to_apic(base, 1, AP_STARTUP_IP >> 12);
    while (read_lapic_reg(base, LAPIC_ICR_LOW32) & ICR_PENDING)
        ;/* wait */
    spin_wait(200);
}

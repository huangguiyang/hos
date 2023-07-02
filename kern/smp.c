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

static void wakeup(void *lapic_base, int apic_id)
{
    // Send INIT-SIPI-SIPI sequence
    send_init_ipi_to_apic(lapic_base, apic_id);
    while (read_lapic_reg(lapic_base, LAPIC_ICR_LOW32) & ICR_PENDING)
        ;/* wait */
    delay_ms(10);
    
    send_startup_ipi_to_apic(lapic_base, apic_id, AP_STARTUP_IP >> 12);
    while (read_lapic_reg(lapic_base, LAPIC_ICR_LOW32) & ICR_PENDING)
        ;/* wait */
    delay_ms(200);
    
    send_startup_ipi_to_apic(lapic_base, apic_id, AP_STARTUP_IP >> 12);
    while (read_lapic_reg(lapic_base, LAPIC_ICR_LOW32) & ICR_PENDING)
        ;/* wait */
}

void smp_init(void)
{
    if (g_lapic_num < 2) return;

    printf("Bring up APs...\n");

    void *base = get_lapic_base_addr();
    int self = get_lapic_id(base);

    for (int i = 0; i < g_lapic_num; i++)
        if (g_lapic[i].apic_id != self)
            wakeup(base, g_lapic[i].apic_id);
    
    while (g_lapic_ative_num != g_lapic_num)
        ;/* wait */

    printf("Done.\n");
}

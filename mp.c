#include "kern.h"

/*
MultiProcessor Initialization
*/

// 4K aligned entry
static int start_ip;

void mp_init(void)
{
    send_init_ipi(ALL_EXCLUDING_SELF, 1);

    send_init_ipi(ALL_INCLUDING_SELF, 0);

    send_startup_ipi(ALL_EXCLUDING_SELF, start_ip >> 12);
    send_startup_ipi(ALL_EXCLUDING_SELF, start_ip >> 12);
}

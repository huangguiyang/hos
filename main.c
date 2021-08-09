#include "kern.h"

int main()
{
    tty_init();
    apic_init();
    mp_init();
    
    printf("Hello, kern64!\n");
    lscpu();

    for (;;);
    return 0;
}

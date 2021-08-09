#include "kern.h"

int main()
{
    struct cpuinfo info;
    int c;

    tty_init();
    
    printf("Hello, kern64!\n");

    info.eax = 1;
    cpuid(&info);
    c = ((info.edx & 0x10000000) >> 28) & 0x1;
    printf("HMT supported: %d\n", c);
    c = ((info.ebx & 0xFF0000) >> 16) & 0xFF;
    printf("Logical Processors: %d\n", c);

    info.eax = 4;
    info.ecx = 0;
    cpuid(&info);
    c = 1 + (((info.eax & 0xFFFF0000) >> 16) & 0xFFFF);
    printf("Cores: %d\n", c);

    for (;;);
    return 0;
}


#include "kern.h"

void main()
{
    sti();

    printf("Hello, world!\n");
    for (;;); // never return
}
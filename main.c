
#include "kern.h"

int a = 7;
int b;

void main()
{
    a = 1;
    sti();

    printf("Hello, world!\n");
    for (;;); // never return
}
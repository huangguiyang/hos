#include "kern.h"

int main()
{
    tty_init();
    
    printf("Hello, kern64!\n");
    lscpu();

    for (;;);
    return 0;
}

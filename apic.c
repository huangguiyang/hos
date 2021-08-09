
#define ICR_LOW32   0xFEE00300
#define ICR_HIGH32  0xFEE00310

void send_init_ipi(int mode, int asrt)
{
    int c;
    
    // INIT, edge, assert
    c = (mode << 18) | (asrt << 14) | (5 << 8);

    *((int *)ICR_HIGH32) = 0;
    *((int *)ICR_LOW32) = c;
}

void send_startup_ipi(int mode, int vector)
{
    int c;

    // STARTUP, edge
    c = (mode << 18) | (6 << 8) | (vector & 0xff);

    *((int *)ICR_HIGH32) = 0;
    *((int *)ICR_LOW32) = c;
}
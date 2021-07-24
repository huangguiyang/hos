
extern void sti(void);
extern int printf(const char *fmt, ...);

int a = 7;
int b;

void main()
{
    a = 1;
    //sti();

    printf("Hello, world!\n");
    for (;;); // never return
}

int printf(const char *fmt, ...)
{
    return 0;
}
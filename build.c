#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>

// 1440k
#define FLOPPY_SIZE (1024 * 1440)

static void die(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    fputs("\n", stderr);
    va_end(ap);
    exit(1);
}

static void usage(void)
{
}

int main(int argc, char *argv[])
{

    return 0;
}

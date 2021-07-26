#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>

#define ASIZE   1024
#define BSIZE   2048
#define CSIZE   (256*1024)      // 不包含BSS

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
    die("Usage: build a b c > image");
}

int main(int argc, char *argv[])
{
    FILE *fp;
    char buf[1024];
    int i, c;

    if (argc < 4)
        usage();
    
    // a
    if (!(fp = fopen(argv[1], "rb")))
        die("can't open file %s", argv[1]);
    i = fread(buf, 1, sizeof buf, fp);
    if (i != 512)
        die("%s must be 512 bytes", argv[1]);
    fclose(fp);
    i = fwrite(buf, 1, 512, stdout);
    if (i != 512)
        die("write failed");
    for (c = 0; i < ASIZE; i++)
        if (fwrite(&c, 1, 1, stdout) != 1)
            die("write failed");
    
    // b
    if (!(fp = fopen(argv[2], "rb")))
        die("can't open file %s", argv[2]);
    for (i = 0; (c = fread(buf, 1, sizeof buf, fp)) > 0; i += c)
        if (fwrite(buf, 1, c, stdout) != c)
            die("write failed");
    fclose(fp);
    if (i > BSIZE)
        die("%s is too big", argv[2]);
    for (c = 0; i < BSIZE; i++)
        if (fwrite(&c, 1, 1, stdout) != 1)
            die("write failed");

    // c
    if (!(fp = fopen(argv[3], "rb")))
        die("can't open file %s", argv[3]);
    for (i = 0; (c = fread(buf, 1, sizeof buf, fp)) > 0; i += c)
        if (fwrite(buf, 1, c, stdout) != c)
            die("write failed");
    fclose(fp);
    if (i > CSIZE)
        die("%s is too big", argv[3]);
    
    fprintf(stderr, "Successfully written.\n");

    return 0;
}

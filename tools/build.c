#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>

// 1440k
#define FLOPPY_SIZE (1024 * 1440)

static int sizes[] = {
    0,
    1024,       // boot sector
    4*1024,     // boot
    128*1024,   // kernel
};

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
    die("Usage: build bootsect boot kern64 > image");
}

int main(int argc, char *argv[])
{
    FILE *fp;
    char buf[1024];
    int i, j, c;

    if (argc < 4)
        usage();

    for (i = 1; i < 4; i++) {
        if (!(fp = fopen(argv[i], "rb")))
            die("can't open file %s", argv[i]);
        for (j = 0; (c = fread(buf, 1, sizeof buf, fp)) > 0; j += c)
            if (fwrite(buf, 1, c, stdout) != c)
                die("write failed");
        fclose(fp);
        if (j > sizes[i])
            die("%s is too big", argv[i]);
        if (i == 1) {
            if (j != 512)
                die("%s must be 512 bytes", argv[i]);
        }

        fprintf(stderr, "%s size %d\n", argv[i], j);

        for (c = 0; j < sizes[i]; j++)
            if (fwrite(&c, 1, 1, stdout) != 1)
                die("write failed");
    }

    for (i = j = 0; i < sizeof(sizes)/sizeof(sizes[0]); i++)
        j += sizes[i];

    for (c = 0; j < FLOPPY_SIZE; j++)
        if (fwrite(&c, 1, 1, stdout) != 1)
            die("write failed");

    fprintf(stderr, "Successfully written.\n");

    return 0;
}

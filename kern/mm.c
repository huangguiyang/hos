#include "kern.h"

static void *free_page(void *p)
{
    int *dirty_map_addr = (int *)DIRTY_MAP_ADDR;
    unsigned int u = p;
    int i = u >> 17;
    int b = (u >> 12) & 31;
    
    dirty_map_addr[i] &= ~(1 << b);
}

static void *alloc_page(void)
{
    int *dirty_map_addr = (int *)DIRTY_MAP_ADDR;
    int b = 0;

    for (int i = 0; i < 4096/sizeof(int); i++) {
        unsigned int k = dirty_map_addr[i];
        for (int j = 0; j < 8 * sizeof(int); j++) {
            if (k & 1) {
                b++;
                k >>= 1;
                continue;
            } else {
                dirty_map_addr[i] |= 1 << j;
                return b << 12L;
            }
        }
    }

    return NULL;
}

static void *alloc_fixed_page(void *p)
{
    int *dirty_map_addr = (int *)DIRTY_MAP_ADDR;
    unsigned int u = p;
    int i = u >> 17;
    int b = (u >> 12) & 31;
    
    dirty_map_addr[i] |= 1 << b;

    return (long)p & ~4095;
}

static void *alloc_page_for_dir(void)
{
    void *p = alloc_page();
    for (int i = 0; i < 4096/8; i++)
        ((unsigned long *)p)[i] = 0;
    return p;
}

void mmap(void *p, int flags)
{
    unsigned long u = p;
    unsigned long *d1, *d2, *d3, *d4;
    int i;
    unsigned long v;

    d1 = PAGE_DIR_ROOT;
    i = (u >> 39) & 511;
    v = d1[i];

    if ((v & 1) == 0) {
        d2 = alloc_page_for_dir();
        // printf("alloc page d2\n");
        d1[i] = (unsigned long)d2 | PAGING_W | PAGING_P;
    } else {
        v = (v << 16) >> 16;
        d2 = (v >> 12) << 12;
    }

    i = (u >> 30) & 511;
    v = d2[i];
    if ((v & 1) == 0) {
        d3 = alloc_page_for_dir();
        // printf("alloc page d3\n");
        d2[i] = (unsigned long)d3 | PAGING_W | PAGING_P;
    } else {
        v = (v << 16) >> 16;
        d3 = (v >> 12) << 12;
    }

    i = (u >> 21) & 511;
    v= d3[i];
    if ((v & 1) == 0) {
        d4 = alloc_page_for_dir();
        // printf("alloc page d4\n");
        d3[i] = (unsigned long)d4 | PAGING_W | PAGING_P;
    } else {
        v = (v << 16) >> 16;
        d4 = (v >> 12) << 12;
    }

    i = (u >> 12) & 511;
    v = d4[i];
    if ((v & 1) == 0) {
        void *p2 = alloc_fixed_page(p);
        d4[i] = (unsigned long)p2 | flags | PAGING_P;
        printf("mapped for %p\n", p);
    } else {
        d4[i] |= flags | PAGING_P;
        printf("already mapped for %p\n", p);
    }
}

void *memset(void *p, int c, unsigned long len)
{
    char *p1, *p2;

    for (p1 = p, p2 = p1 + len; p1 < p2; p1++)
        *p1 = c;

    return p;
}

void *memcpy(void *dst, void *src, unsigned long len)
{
    char *d = dst;
    char *s = src;

    for (int i = 0; i < len; i++)
        *d++ = *s++;

    return dst;
}

int memcmp(void *a, void *b, unsigned long len)
{
    unsigned char *p1 = a;
    unsigned char *p2 = b;
    int n = 0, i;

    for (i = 0; i < len; i++, p1++, p2++) {
        if (*p1 < *p2)
            return -1;
        if (*p1 > *p2)
            return 1;
    }

    return n;
}

void mm_init(void)
{
    //TODO:根据实际内存大小
    // 先按照4GB
    int *dirty_map_addr = (int *)DIRTY_MAP_ADDR;
    int n = 0x100000 / (4096 * sizeof(int) * 8);
    //1MB以内全部标记
    for (int i = 0; i < DIRTY_MAP_SIZE/sizeof(int); i++)
        dirty_map_addr[i] = i < n ? 0xFFFFFFFF : 0;
}

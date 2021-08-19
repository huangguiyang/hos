#include "kern.h"

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

/*
    https://bochs.sourceforge.io/techspec/PORTS.LST

    彩色显示器
    内存范围：0xB8000 - 0XBFFFF，共32KB
    支持8页，每页 80列 x 25行
    每个字符255个属性，占两个字节，因此一页内容4000字节
    
    读取光标位置
    索引寄存器：0x03D4
               0x0E - 光标位置高8位
               0x0F - 光标位置低8位
    数据寄存器：0x03D5
*/

// 读取光标位置
int read_cursor(void)
{
    int low, high;

    outb(0x03d4, 0x0e);
    inb(0x03d5, &high);
    outb(0x03d4, 0x0f);
    inb(0x03d5, &low);
    
    return (high << 8) | low;
}

// 设置光标位置
void set_cursor(int position)
{
    outb(0x03d4, 0x0e);
    outb(0x03d5, position >> 8);
    outb(0x03d4, 0x0f);
    outb(0x03d5, position & 0xff);
}

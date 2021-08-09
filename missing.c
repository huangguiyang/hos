#include "kern.h"

void *memset(void *p, int c, unsigned long len)
{
    char *p1, *p2;

    for (p1 = p, p2 = p1 + len; p1 < p2; p1++)
        *p1 = c;

    return p;
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

int cpuid_max(void)
{
    struct cpuinfo info;

    info.eax = 0;
    cpuid(&info);
    return info.eax;
}

// 是否支持硬件多线程 (Hardware Multi-Threading)
int hmt_supported_p(void)
{
    struct cpuinfo info;

    info.eax = 1;
    cpuid(&info);
    return (info.edx >> 28) & 1;
}

// 逻辑处理器个数
int n_logical_processors(void)
{
    struct cpuinfo info;

    info.eax = 1;
    cpuid(&info);
    return (info.ebx >> 16) & 0xff;
}

// 核心数
int n_cores(void)
{
    struct cpuinfo info;

    info.eax = 4;
    info.ecx = 0;
    cpuid(&info);
    return 1 + ((info.eax >> 16) & 0xff);
}

void lscpu(void)
{
    printf("CPUID MAX: %d\n", cpuid_max());
    printf("HMT supported: %d\n", hmt_supported_p());
    printf("Logical Processors: %d\n", n_logical_processors());
    printf("Cores: %d\n", n_cores());
}
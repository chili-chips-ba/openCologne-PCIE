//=====================================================================
//
// mem.c                                              Date: 2021/08/01
//
// Copyright (c) 2021 Simon Southwell
//
//=====================================================================

// -------------------------------------------------------------------------
// INCLUDES
// -------------------------------------------------------------------------

#include "mem.h"

// -------------------------------------------------------------------------
// STATICS
// -------------------------------------------------------------------------

static pPrimaryTbl_t PrimaryTable[MAX_NODES];

// -------------------------------------------------------------------------
// InitialiseMem()
//
// Intiliases memory table to a NULL state
//
// -------------------------------------------------------------------------

void InitialiseMem (int node)
{
    PrimaryTable[node] = NULL;
}

// -------------------------------------------------------------------------
// InitialisePrimaryTable()
//
// Invalidates all entries in the memory primary table
//
// -------------------------------------------------------------------------

static void InitialisePrimaryTable (const pPrimaryTbl_t table)
{
    int i;

    for (i = 0; i < TABLESIZE; i++)
    {
        table[i].valid = false;
    }
}

// -------------------------------------------------------------------------
// InitialiseTable()
//
// Initialise a secondary table
//
// -------------------------------------------------------------------------

static void InitialiseTable (char **table)
{
    int i;

    for (i = 0; i < TABLESIZE; i++)
    {
        table[i] = NULL;
    }
}

// -------------------------------------------------------------------------
// bitrev()
//
// An efficient bit reverse, up to 32 bits.
//
// -------------------------------------------------------------------------

static uint32_t bitrev(const uint32_t Data, const int bits)
{
    unsigned long result = Data;
    int i;

    // Compare each of the bottom bits with reflected top bits
    for (i = 0; i < bits/2; i++)
    {
        // If top and bottom bits different, invert both bits
        if (((result >> (bits-1-i*2)) ^ result) & (1 << i))
        {
            result ^= (1 << i) | (1 << (bits-1-i));
        }
    }

    return result & ((1 << bits) - 1);
}

// -------------------------------------------------------------------------
// GenHash12()
//
// A cheap and cheerful hash
//
// -------------------------------------------------------------------------

static uint32_t GenHash12(const uint64_t addr)
{
    uint64_t munge = 0;

    munge ^= (addr >> 52) & 0xfffULL;
    munge ^= (addr >> 40) & 0xfffULL;
    munge ^= (addr >> 32) & 0xffULL;
    munge ^= (addr >> 24) & 0xffULL;

    return bitrev((uint32_t) (munge & 0xfffULL), 12);
}

// -------------------------------------------------------------------------
// WriteRamByteBlock()
//
// Write a block of data to memory
//
// -------------------------------------------------------------------------

void WriteRamByteBlock(const uint64_t addr, const PktData_t *data, const int fbe, int const lbe, const int length, const uint32_t node)
{
    uint32_t pidx, sidx, offset;
    int idx;

    idx = pidx = GenHash12(addr);
    sidx = (addr >> 12) & TABLEMASK;
    offset = addr & TABLEMASK;

    if ((addr & ~TABLEMASK) != ((addr + length - 1) & ~TABLEMASK))
    {
        printf("WriteRamByteBlock: ***Error --- block write crosses 4K boundary (addr=0x%llx len=0x%x\n", (long long unsigned)addr, length);
    }

    // No primary table, so allocate some space for one and initialise
    if (PrimaryTable[node] == NULL)
    {
        if ((PrimaryTable[node] = malloc(TABLESIZE * sizeof(PrimaryTbl_t))) == NULL)
        {
            printf("WriteRamByteBlock: ***Error --- failed to allocate primary table memory\n");
        }
        InitialisePrimaryTable(PrimaryTable[node]);
    }

    // Whilst we have a collision, increment primary offset until an invalid entry, or we matched address
    while (PrimaryTable[node][pidx].valid && PrimaryTable[node][pidx].addr != (addr & 0xffffffffff000000ULL))
    {
        pidx = (pidx+1) % TABLESIZE;

        // If we have searched through the whole table....
        if (pidx == idx)
        {
            printf("WriteRamByteBlock: ***Error --- ran out of primary table space\n");
        }
    }

    // If first time we have written to this block, validate it
    if (!PrimaryTable[node][pidx].valid)
    {
        PrimaryTable[node][pidx].valid = true;
        PrimaryTable[node][pidx].addr = (addr & 0xffffffffff000000ULL);
        PrimaryTable[node][pidx].p = NULL;
    }

    // No secondary table, so allocate some space for one and initialise
    if (PrimaryTable[node][pidx].p == NULL)
    {
        if ((PrimaryTable[node][pidx].p = malloc(TABLESIZE * sizeof(uint32_t *))) == NULL)
        {
            printf("WriteRamByteBlock: ***Error --- failed to allocate secondary table memory\n");
            //VWrite(PVH_FATAL, 0, 0, node);
        }
        InitialiseTable(PrimaryTable[node][pidx].p);
    }

    // No memory block allocated, so allocate some space
    if (PrimaryTable[node][pidx].p != NULL)
    {
        if ((PrimaryTable[node][pidx].p)[sidx] == NULL)
        {
            if (((PrimaryTable[node][pidx].p)[sidx] = malloc(TABLESIZE)) == NULL)
            {
                printf("WriteRamByteBlock: ***Error --- failed to allocate memory\n");
            }
        }
    }

    for (idx = 0; idx < length; idx++)
    {
        if ( (idx < 4 && ((1<<idx) & fbe)) ||
             (idx >= (length-4) && ((1<<(4-(length-idx))) & lbe)) ||
             (idx >= 4 && idx < (length-4)))
        {
            if (PrimaryTable[node][pidx].p != NULL)
            {
                if ((PrimaryTable[node][pidx].p)[sidx] != NULL)
                {
                    ((char*)((PrimaryTable[node][pidx].p)[sidx]))[(idx + offset) % TABLESIZE] = (char)data[idx];
                }
            }
        }
    }
}

// -------------------------------------------------------------------------
// ReadRamByteBlock()
//
// Read a block of data from memory.
//
// -------------------------------------------------------------------------

int ReadRamByteBlock(const uint64_t addr, PktData_t *data, const int length, const uint32_t node)
{
    uint32_t pidx, sidx, offset;
    int idx;

    idx = pidx = GenHash12(addr);
    sidx = (addr >> 12) & TABLEMASK;
    offset = addr & TABLEMASK;

    if ((addr & ~TABLEMASK) != ((addr + length-1) & ~TABLEMASK))
    {
        printf("ReadRamByteBlock: ***Error --- block read crosses 4K boundary\n");
    }

    if (PrimaryTable[node] == NULL)
    {
        Debugprintf("ReadRamByteBlock: ***Error --- reading from uninitialised primary table\n");
        return MEM_BAD_STATUS;
    }

    // Whilst we have detected a collision, increment primary offset until an invalid entry or we matched address
    while (PrimaryTable[node][pidx].valid && PrimaryTable[node][pidx].addr != (addr & 0xffffffffff000000ULL))
    {
        pidx = (pidx+1) % TABLESIZE;

        // If we searched the whole table...
        if (pidx == idx)
        {
            printf("ReadRamByteBlock: ***Error --- address does not exist in primary table\n");
        }
    }

    // No secondary table, so flag an error
    if (PrimaryTable[node][pidx].p == NULL)
    {
        Debugprintf("ReadRamByteBlock: ***Error --- reading from uninitialised secondary table\n");
        return MEM_BAD_STATUS;
    }

    // No memory block allocated, so flag an error
    if ((PrimaryTable[node][pidx].p)[sidx] == NULL)
    {
        Debugprintf("ReadRamByteBlock: ***Error --- reading from uninitialised memory block\n");
        return MEM_BAD_STATUS;
    }

    for (idx = 0; idx < length; idx++)
    {
        data[idx] = ((char *)(PrimaryTable[node][pidx].p)[sidx])[idx+offset] & 0xff;
    }

    return MEM_GOOD_STATUS;
}

// -------------------------------------------------------------------------
// WriteRamByte()
//
// Write a data byte to memory.
//
// -------------------------------------------------------------------------

void WriteRamByte(const uint64_t inaddr, const uint32_t data, const uint32_t node)
{
    uint64_t addr;
    int addr_lo, fbe;
    PktData_t buf[4];

    addr = inaddr & ~3ULL;
    addr_lo = (int)(inaddr & 3ULL);
    fbe  = 0x1 << addr_lo;
    buf[addr_lo] = data & 0xff;

    WriteRamByteBlock (addr, buf, fbe, 0, 4, node);
}

// -------------------------------------------------------------------------
// WriteRamHWord()
//
// Write a data half word to memory.
//
// -------------------------------------------------------------------------

void WriteRamHWord (const uint64_t addr, const uint32_t data, const int le, const uint32_t node)
{
    uint32_t data_out;
    int addr_lo, fbe;
    PktData_t buf[4];
    int i;

    addr_lo  =  (int)(addr & 2ULL);
    fbe      = 0x3 << addr_lo;
    data_out = (addr_lo) ? (data << 16) : data;

    for (i = 0; i < 4; i++)
    {
        buf[i] = (le ? (data_out >> (i*8))  & 0xffffUL: (data_out >> ((3-i)*8))) & 0xff;
    }

    WriteRamByteBlock (addr & ~3ULL, buf, fbe, 0x0, 4, node);
}

// -------------------------------------------------------------------------
// WriteRamWord()
//
// Write a data word to memory.
//
// -------------------------------------------------------------------------

void WriteRamWord (const uint64_t addr, const uint32_t data, const int le, const uint32_t node)
{
    PktData_t buf[4];
    int i;

    for (i = 0; i < 4; i++)
    {
        buf[i] = (le ? (data >> (i*8)) : (data >> ((3-i)*8))) & 0xff;
    }

    WriteRamByteBlock (addr & ~3ULL, buf, 0xf, 0x0, 4, node);
}

// -------------------------------------------------------------------------
// WriteRamDWord()
//
// Write a double data word (64 bits) to memory.
//
// -------------------------------------------------------------------------

void WriteRamDWord (const uint64_t addr, const uint64_t data, const int le, const uint32_t node)
{
    PktData_t buf[8];
    int i;

    for (i = 0; i < 8; i++)
    {
        buf[i] = (PktData_t) (le ? (data >> (i*8)) : (data >> ((7-i)*8))) & 0xffULL;
    }

    WriteRamByteBlock (addr & ~7ULL, buf, 0xf, 0xf, 8, node);
}

// -------------------------------------------------------------------------
// ReadRamByte()
//
// Read a byte from memory
//
// -------------------------------------------------------------------------

uint32_t ReadRamByte (const uint64_t addr, const uint32_t node)
{
    PktData_t buf[4];
    int i;

    // If ReadRamByteBlock fails, return 0
    if (ReadRamByteBlock (addr & ~3ULL, buf, 4, node))
    {
        return 0;
    }

    i = (int)(addr & 3ULL);

    return buf[i];
}

// -------------------------------------------------------------------------
// ReadRamHWord()
//
// Read a half word from memory
//
// -------------------------------------------------------------------------

uint32_t ReadRamHWord (const uint64_t addr, const int le, const uint32_t node)
{
    PktData_t buf[4];
    uint32_t data = 0;
    int addr_lo = addr & 0x2;
    int i;

    // If ReadRamByteBlock fails, return 0
    if (ReadRamByteBlock (addr & ~3ULL, buf, 4, node))
    {
        return 0;
    }

    for (i = addr_lo; i < (2+addr_lo); i++)
    {
        data |= (buf[i] & 0xff) << (le ? (i*8) : ((3-i)*8));
    }

    return (addr_lo) ? (data >> 16) : data;
}

// -------------------------------------------------------------------------
// ReadRamWord()
//
// Read a word from memory
//
// -------------------------------------------------------------------------

uint32_t ReadRamWord (const uint64_t addr, const int le, const uint32_t node)
{
    PktData_t buf[4];
    uint32_t data = 0;
    int i;

    // If ReadRamByteBlock fails, return 0
    if (ReadRamByteBlock (addr & ~3ULL, buf, 4, node))
    {
        return 0;
    }

    for (i = 0; i < 4; i++)
    {
        data |= (buf[i] & 0xff) << (le ? (i*8) : ((3-i)*8));
    }

    return data;
}

// -------------------------------------------------------------------------
// ReadRamDWord()
//
// Read a double word (64 bits) from memory
//
// -------------------------------------------------------------------------

uint64_t ReadRamDWord (const uint64_t addr, const int le, const uint32_t node)

{
    PktData_t buf[8];
    uint64_t data = 0;
    int i;

    // If ReadRamByteBlock fails, return 0
    if (ReadRamByteBlock (addr & ~7ULL, buf, 8, node))
    {
        return 0ULL;
    }

    for (i = 0; i < 8; i++)
    {
        data |= ((uint64_t)(buf[i] & 0xff)) << (le ? (i*8) : ((7-i)*8));
    }

    return data;
}


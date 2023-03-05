// sim8086.cpp

#include "types.h"

#include <stdio.h>
#include <stdlib.h>

#if SIM86_DEBUG
#define assert(x) if (!(x)) { __debugbreak(); }
#else
#define assert(x)
#endif

char *register_table [] = {
                      //    W MOD REG/R_M
    "[bx + si]",      // 0b 0 00  000
    "[bx + di]",      // 0b 0 00  001
    "[bp + si]",      // 0b 0 00  010
    "[bp + di]",      // 0b 0 00  011
    "[si]",           // 0b 0 00  100
    "[di]",           // 0b 0 00  101
    "unknown",        // 0b 0 00  110
    "[bx]",           // 0b 0 00  111
                              
    "[bx + si + 8]",  // 0b 0 01  000
    "[bx + di + 8]",  // 0b 0 01  001
    "[bp + si + 8]",  // 0b 0 01  010
    "[bp + di + 8]",  // 0b 0 01  011
    "[si + 8]",       // 0b 0 01  100
    "[di + 8]",       // 0b 0 01  101
    "[bp + 8]",       // 0b 0 01  110
    "[bx + 8]",       // 0b 0 01  111
                              
    "[bx + si + 16]", // 0b 0 10  000
    "[bx + di + 16]", // 0b 0 10  001
    "[bp + si + 16]", // 0b 0 10  010
    "[bp + di + 16]", // 0b 0 10  011
    "[si + 16]",      // 0b 0 10  100
    "[di + 16]",      // 0b 0 10  101
    "[bp + 16]",      // 0b 0 10  110
    "[bx + 16]",      // 0b 0 10  111
                              
    "al",             // 0b 0 11  000
    "cl",             // 0b 0 11  001
    "dl",             // 0b 0 11  010
    "bl",             // 0b 0 11  011
    "ah",             // 0b 0 11  100
    "ch",             // 0b 0 11  101
    "dh",             // 0b 0 11  110
    "bh",             // 0b 0 11  111
                              
    "ax",             // 0b 1 00  000
    "cx",             // 0b 1 00  001
    "dx",             // 0b 1 00  010
    "bx",             // 0b 1 00  011
    "sp",             // 0b 1 00  100
    "bp",             // 0b 1 00  101
    "si",             // 0b 1 00  110
    "di",             // 0b 1 00  111

    "error",          // 0b 1 01  000
    "error",          // 0b 1 01  001
    "error",          // 0b 1 01  010
    "error",          // 0b 1 01  011
    "error",          // 0b 1 01  100
    "error",          // 0b 1 01  101
    "error",          // 0b 1 01  110
    "error",          // 0b 1 01  111

    "error",          // 0b 1 10  000
    "error",          // 0b 1 10  001
    "error",          // 0b 1 10  010
    "error",          // 0b 1 10  011
    "error",          // 0b 1 10  100
    "error",          // 0b 1 10  101
    "error",          // 0b 1 10  110
    "error",          // 0b 1 10  111

    "ax",             // 0b 1 11  000
    "cx",             // 0b 1 11  001
    "dx",             // 0b 1 11  010
    "bx",             // 0b 1 11  011
    "sp",             // 0b 1 11  100
    "bp",             // 0b 1 11  101
    "si",             // 0b 1 11  110
    "di",             // 0b 1 11  111
};

static u8 *instruction_pointer;
static u8 *instruction_start;
static u8 *instruction_end;


u8 eat_byte()
{
    u8 byte = *instruction_pointer;
    instruction_pointer += 1;
    assert(instruction_pointer <= instruction_end);
    return byte;
};

int main(int args_count, char *args[])
{
    if (args_count == 1) return 0;

    FILE *in_file = 0;
    if (fopen_s(&in_file, args[1], "rb"))
    {
        printf("ERROR: File '%s' could not be opened.\n", args[1]);
        return 1;
    }


    fseek(in_file, 0, SEEK_END);
    s64 size = ftell(in_file);
    fseek(in_file, 0, SEEK_SET);

    instruction_start  = (u8  *)malloc(size * sizeof(u8));
    instruction_end    = instruction_start + size;
    fread(instruction_start, sizeof(u8), size, in_file);
    fclose(in_file);

    instruction_pointer = instruction_start;

    printf("bits 16\n");
    while (instruction_pointer < instruction_end) {
        u8 instruction = eat_byte();
        if (((instruction >> 2) & 0b111111) == 0b100010)
        {
            u8 w      = (instruction & 1) << 5;
            u8 d_flag = (instruction >> 1) & 1;
            d_flag = ((d_flag     ) |
                      (d_flag << 1) |
                      (d_flag << 2) |
                      (d_flag << 3) |
                      (d_flag << 4) |
                      (d_flag << 5));
            u8 inv_d_flag = 0b111111 - d_flag;

            u8 mov_extra0 = eat_byte();
            u8 mod =   mov_extra0 >> 6;
            u8 reg = ((mov_extra0 >> 3) & 0b111) | w | (0b11 << 3); // for the REG field, we always use a 'mod' of 0b11
            u8 r_m = ((mov_extra0     ) & 0b111) | w | ( mod << 3);


#if 0
            if (mod == 0b00)
            {
                printf("mov 00\n");
            }
            else if (mod == 0b01)
            {
                printf("mov 01\n");
            }
            else if (mod == 0b10)
            {
                printf("mov 10\n");
            }
            else if (mod == 0b11)
            {
#endif
                u8 src = ((reg & inv_d_flag) |
                          (r_m &     d_flag));
                u8 dst = ((reg &     d_flag) |
                          (r_m & inv_d_flag));

                printf("mov %s, %s\n", register_table[dst], register_table[src]);
#if 0
            }
#endif
        }
        else if ((instruction >> 4) == 0b1011)
        {
            u8 w   = (instruction & 0b1000) << 2;
            u8 reg = (instruction & 0b0111) | w;

            u16 data = eat_byte();
            if (w)
                data = data | (eat_byte() << 8);

            printf("mov %s, %d\n", register_table[reg], data);
        }

    }

    
    return 0;
}

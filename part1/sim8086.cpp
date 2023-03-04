// sim8086.cpp

#include "types.h"

#include <stdio.h>
#include <stdlib.h>

char *register_table [] = {
    "al", // 0b0000
    "cl", // 0b0001
    "dl", // 0b0010
    "bl", // 0b0011
    "ah", // 0b0100
    "ch", // 0b0101
    "dh", // 0b0110
    "bh", // 0b0111

    "ax", // 0b1000
    "cx", // 0b1001
    "dx", // 0b1010
    "bx", // 0b1011
    "sp", // 0b1100
    "bp", // 0b1101
    "si", // 0b1110
    "di", // 0b1111
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

    u8  *buf8  = (u8  *)malloc(size * sizeof(u8));

    fread(buf8, sizeof(u8), size, in_file);

    fclose(in_file);



    u16 *instruction_counter = (u16 *)buf8;
    u16 *instruction_end     = instruction_counter + (size / sizeof(u16));

    int x = 15;

    printf("bits 16\n");
    while (instruction_counter != instruction_end) {
        u16 instruction = *instruction_counter;
        if (((instruction >> 2) & 0b111111) == 0b100010)
        {
            u8 w      = (instruction & 1) << 3;
            u8 d_flag = (instruction >> 1) & 1;
            d_flag = ((d_flag     ) |
                      (d_flag << 1) |
                      (d_flag << 2) |
                      (d_flag << 3));
            u8 inv_d_flag = 0b1111 - d_flag;

            u8 reg = (u8)(instruction >> (8 + 3) & 0b111) | w;
            u8 r_m = (u8)(instruction >> (8    ) & 0b111) | w;

            u8 src = ((reg & inv_d_flag) |
                      (r_m &     d_flag));
            u8 dst = ((reg &     d_flag) |
                      (r_m & inv_d_flag));

            printf("mov %s, %s\n", register_table[dst], register_table[src]);

        }

        instruction_counter += 1;
    }

    
    return 0;
}

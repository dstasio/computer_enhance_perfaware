// sim8086.cpp

#include "types.h"

#include <stdio.h>
#include <stdlib.h>

#if SIM86_DEBUG
#define assert(x) if (!(x)) { __debugbreak(); }
#else
#define assert(x)
#endif

void print_binary(u16 n)
{
    s8 index = (n <= 0xFF) ? 8 : 16;
    index -= 1;
    while (index >= 0)
    {
        printf("%c", '0' + ((n >> index) & 1));

        index -= 1;
        if (index == 3 || index == 7 || index == 11)
            printf("_");
    }
}

char *memory_locations[] = {
                    //    REG
    "bx + si",      // 0b 000
    "bx + di",      // 0b 001
    "bp + si",      // 0b 010
    "bp + di",      // 0b 011
    "si",           // 0b 100
    "di",           // 0b 101
    "",             // 0b 110
    "bx",           // 0b 111
};

char *register_table[] = {
                      //    W REG/R_M
    "al",             // 0b 0 000
    "cl",             // 0b 0 001
    "dl",             // 0b 0 010
    "bl",             // 0b 0 011
    "ah",             // 0b 0 100
    "ch",             // 0b 0 101
    "dh",             // 0b 0 110
    "bh",             // 0b 0 111
                              
    "ax",             // 0b 1 000
    "cx",             // 0b 1 001
    "dx",             // 0b 1 010
    "bx",             // 0b 1 011
    "sp",             // 0b 1 100
    "bp",             // 0b 1 101
    "si",             // 0b 1 110
    "di",             // 0b 1 111
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



struct String_Buffer
{
    char data[30];
};

#define arr_len(arr) (sizeof(arr)/sizeof((arr)[0]))
// will advance instruction pointer by calling eat_byte when necessary
String_Buffer do_mod_r_m(u8 mod, u8 r_m, u8 w)
{
    String_Buffer result = {};

    w = w << 3;
    if (mod == 0b11)
    {
        sprintf_s(result.data, arr_len(result.data), "%s", register_table[r_m | w]);
    }
    else 
    {
#define MAX_MEMORY_ADDRESS_STRING_LENGTH 9
        s16  disp                                          = 0;
        char disp_string[MAX_MEMORY_ADDRESS_STRING_LENGTH] = {};

        if (mod == 0b01)
        {
            disp = (s8)eat_byte();
        }
        else if ((mod == 0b10) || (r_m == 0b110))
        {
            disp = eat_byte();
            disp = disp | (eat_byte() << 8);
        }

        if (disp)
        {
            sprintf_s(disp_string, arr_len(disp_string), "%d", disp);
        }

        char *memory_address_string = memory_locations[r_m];
        if ((mod) && (r_m == 0b110))
            memory_address_string = "bp";
        sprintf_s(result.data, arr_len(result.data), "[%s%s%s]", memory_address_string, (memory_address_string[0] && disp_string[0]) ? " + " : "", disp_string);
    }

    return result;
}

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
            u8 w      = (instruction & 1) << 3;
            u8 d_flag = (instruction >> 1) & 1;
            d_flag = ((d_flag     ) |
                      (d_flag << 1) |
                      (d_flag << 2) |
                      (d_flag << 3));
            u8 inv_d_flag = 0b111111 - d_flag;

            u8 mov_extra0 = eat_byte();
            u8 mod =   mov_extra0 >> 6;
            u8 reg = ((mov_extra0 >> 3) & 0b111) | w;
            u8 r_m = ((mov_extra0     ) & 0b111);


            String_Buffer r_m_string = do_mod_r_m(mod, r_m, w >> 3);
            if (d_flag)
                printf("mov %s, %s\n", register_table[reg], r_m_string.data);
            else
                printf("mov %s, %s\n", r_m_string.data, register_table[reg]);
        }
        else if ((instruction >> 1) == 0b1100011) // mov immediate to register/memory
        {
            u8 w          = (instruction & 1);

            u8 mov_extra0 = eat_byte();

            u8 mod = mov_extra0 >> 6;
            u8 r_m = mov_extra0 & 0b111;

            String_Buffer r_m_string = do_mod_r_m(mod, r_m, w);

            u16 data = eat_byte();
            if (w)
                data = data | (eat_byte() << 8);

            printf("mov %s, %s%d\n", r_m_string.data, (w) ? "word " : "byte ", data);
        }
        else if ((instruction >> 4) == 0b1011)    // mov immediate to register
        {
            u8 w   = (instruction & 0b1000);
            u8 reg = (instruction & 0b0111) | w;

            u16 data = eat_byte();
            if (w)
                data = data | (eat_byte() << 8);

            printf("mov %s, %d\n", register_table[reg], data);
        }
        else
        {
            printf("unknown: %x    ", instruction);
            print_binary(instruction);
            printf("\n");
        }

    }

    
    return 0;
}

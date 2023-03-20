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

u8 peek_byte()
{
    return *instruction_pointer;
};



char *get_string_for_opcode(u8 op_code)
{

    if      (op_code == 0)
        return "add";
    else if (op_code == 0b101)
        return "sub";
    else if (op_code == 0b111)
        return "cmp";
    return 0;
}

struct R_M_String
{
    char data[30];
    char size[6];
};

#define arr_len(arr) (sizeof(arr)/sizeof((arr)[0]))
// will advance instruction pointer by calling eat_byte when necessary
R_M_String do_mod_r_m(u8 mod, u8 r_m, u8 w)
{
    R_M_String result = {};

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
        sprintf_s(result.size, arr_len(result.size), "%s", (w) ? "word " : "byte ");
    }

    return result;
}


// will advance instruction pointer by calling eat_byte when necessary
void do_d_w_mod_reg_rm(u8 instruction, char *op)
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


    R_M_String r_m_string = do_mod_r_m(mod, r_m, w >> 3);
    if (d_flag)
        printf("%s %s, %s\n", op, register_table[reg], r_m_string.data);
    else
        printf("%s %s, %s\n", op, r_m_string.data, register_table[reg]);
}

// will advance instruction pointer by calling eat_byte when necessary
void do_s_w_mod_rm_disp_data(u8 instruction, char *op, bool print_size)
{
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

    printf("bits 16\n\n");
    while (instruction_pointer < instruction_end) {
        u8 instruction = eat_byte();
        if ((instruction >> 2) == 0b100010)     // mov register/memory to/from register
        {
            do_d_w_mod_reg_rm(instruction, "mov");
        }
        else if (((instruction >> 2) & 0b110001) == 0)
        {
            // 0b000000 == add  reg/memory with register to either
            // 0b001010 == sub  reg/memory and register to either
            // 0b001110 == cmp  register/memory and register
            u8    op_code = (instruction >> 3) & 0b111;
            char *op      = get_string_for_opcode(op_code);

            if (op)
                do_d_w_mod_reg_rm(instruction, op);
            else
            {
                printf("unknown op: register/memory to/from register   --> ");
                print_binary(instruction);
                printf("\n");
            }
        }

        else if ((instruction >> 1) == 0b1100011) // mov immediate to register/memory
        {
            u8 w          = (instruction & 1);

            u8 mov_extra0 = eat_byte();

            u8 mod = mov_extra0 >> 6;
            u8 r_m = mov_extra0 & 0b111;

            R_M_String r_m_string = do_mod_r_m(mod, r_m, w);

            u16 data = eat_byte();
            if (w)
                data = data | (eat_byte() << 8);

            printf("mov %s, %s%d\n", r_m_string.data, (w) ? "word " : "byte ", data);
        }
        else if ((instruction >> 2) == 0b100000)
        {
            u8    op_code = (peek_byte() >> 3) & 0b111;
            char *op      = get_string_for_opcode(op_code);

            if (!op)
            {
                printf("unknown op: register/memory to/from register   --> ");
                print_binary(instruction);
                printf("\n");
            }
            else
            {
                u8 w          = (instruction     ) & 1;
                u8 s          = (instruction >> 1) & 1;

                u8 mov_extra0 = eat_byte();

                u8 mod = mov_extra0 >> 6;
                u8 r_m = mov_extra0 & 0b111;

                R_M_String r_m_string = do_mod_r_m(mod, r_m, w);

                s16 data;
                if (!s && w)
                {
                    data = eat_byte();
                    data = data | (eat_byte() << 8);
                }
                else
                    data = (s16)eat_byte();

                if (s)
                    printf("%s %s%s, %d\n", op, (r_m_string.data[0] == '[') ? r_m_string.size : "", r_m_string.data, data);
                else
                    printf("%s %s%s, %u\n", op, (r_m_string.data[0] == '[') ? r_m_string.size : "", r_m_string.data, data);
            }
        }

        else if ((instruction >> 4) == 0b1011)    // mov immediate to register
        {
            u8 w   = (instruction & 0b1000);
            u8 reg = (instruction & 0b0111) | w;

            u16 data = eat_byte();
            if (w)
                data |= eat_byte() << 8;

            printf("mov %s, %d\n", register_table[reg], data);
        }

        else if ((instruction >> 2) == 0b101000) // memory to accumulator / accumulator to memory
        {
            u8 w         = (instruction     ) & 1;
            u8 direction = (instruction >> 1) & 1;

            u16 addr = eat_byte();
            addr |= eat_byte() << 8;

            if (direction)
                printf("mov [%d], ax\n", addr);
            else
                printf("mov ax, [%d]\n", addr);
        }

        else if (((instruction >> 1) & 0b1100011) == 0b10)
        {
            // 0b0000010 == add immediate to accumulator
            // 0b0010110 == sub immediate from accumulator
            // 0b0011110 == cmp immediate with accumulator
            u8    op_code = (instruction >> 3) & 0b111;
            char *op      = get_string_for_opcode(op_code);

            if (!op)
            {
                printf("unknown op: register/memory to/from register   --> ");
                print_binary(instruction);
                printf("\n");
            }
            else
            {
                u8 w = instruction & 1;

                s16 data;
                if (w)
                {
                    data = (s16)eat_byte();
                    data = data | (eat_byte() << 8);
                }
                else
                {
                    u8 b = eat_byte();
                    data = *((s8*)&b);
                }


                printf("%s %s, %d\n", op, (w) ? "ax" : "al", data);
            }
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

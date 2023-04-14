// sim8086.cpp

#include "types.h"

#include <stdio.h>
#include <stdlib.h>
#include <cstring>

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

char *register_name_table[] = {
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


enum Register_Index
{
    ax,
    bx,
    cx,
    dx,

    sp,
    bp,
    di,
    si,
};

struct Register_Pointer
{
    Register_Index index;
    u16            mask;
    u16            shift;
};

Register_Pointer register_pointer_table[] = {
                         //    W REG/R_M
    { ax, 0x00FF, 0 },   // 0b 0 000
    { cx, 0x00FF, 0 },   // 0b 0 001
    { dx, 0x00FF, 0 },   // 0b 0 010
    { bx, 0x00FF, 0 },   // 0b 0 011
    { ax, 0xFF00, 8 },   // 0b 0 100
    { cx, 0xFF00, 8 },   // 0b 0 101
    { dx, 0xFF00, 8 },   // 0b 0 110
    { bx, 0xFF00, 8 },   // 0b 0 111

    { ax, 0xFFFF, 0 },   // 0b 1 000
    { cx, 0xFFFF, 0 },   // 0b 1 001
    { dx, 0xFFFF, 0 },   // 0b 1 010
    { bx, 0xFFFF, 0 },   // 0b 1 011
    { sp, 0xFFFF, 0 },   // 0b 1 100
    { bp, 0xFFFF, 0 },   // 0b 1 101
    { si, 0xFFFF, 0 },   // 0b 1 110
    { di, 0xFFFF, 0 },   // 0b 1 111
};


// =========================================
// State variables
//
static u8 *instruction_pointer;
static u8 *instruction_start;
static u8 *instruction_end;
static u16 registers[8];

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

struct Mod_R_M_Result
{
    bool             is_memory;
    Register_Pointer register_pointer;

    char string_data[30];
    char string_size[6];
};

#define arr_len(arr) (sizeof(arr)/sizeof((arr)[0]))
// will advance instruction pointer by calling eat_byte when necessary
Mod_R_M_Result do_mod_r_m(u8 mod, u8 r_m, u8 w)
{
    Mod_R_M_Result result = {};

    w = w << 3;
    if (mod == 0b11)
    {
        sprintf_s(result.string_data, arr_len(result.string_data), "%s", register_name_table[r_m | w]);
        result.register_pointer = register_pointer_table[r_m | w];
    }
    else 
    {
        result.is_memory = true;
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
        sprintf_s(result.string_data, arr_len(result.string_data), "[%s%s%s]", memory_address_string, (memory_address_string[0] && disp_string[0]) ? " + " : "", disp_string);
        sprintf_s(result.string_size, arr_len(result.string_size), "%s", (w) ? "word " : "byte ");
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


    Mod_R_M_Result r_m_result = do_mod_r_m(mod, r_m, w >> 3);
    if (d_flag)
        printf("%s %s, %s", op, register_name_table[reg], r_m_result.string_data);
    else
        printf("%s %s, %s", op, r_m_result.string_data, register_name_table[reg]);


    if ((strcmp(op, "mov") == 0) && (!r_m_result.is_memory)) {
        auto   dest_reg = d_flag ? register_pointer_table[reg] : r_m_result.register_pointer;
        auto source_reg = d_flag ? r_m_result.register_pointer : register_pointer_table[reg];
        assert((dest_reg.mask >> dest_reg.shift) == (source_reg.mask >> source_reg.shift));

        u16 *  dest_reg_ptr = &registers[  dest_reg.index];
        u16 *source_reg_ptr = &registers[source_reg.index];

        u16 prev_register_data = *dest_reg_ptr;

        u16 data = ((*source_reg_ptr) >> source_reg.shift) & source_reg.mask;
        data <<= dest_reg.shift;
        data  &= dest_reg.mask;
        (*dest_reg_ptr) &= ~dest_reg.mask;
        (*dest_reg_ptr) |= data;

        printf("  ; %s:0x%x -> 0x%x\n", d_flag ? register_name_table[reg] : r_m_result.string_data, prev_register_data, *dest_reg_ptr);
    }
    else {
        printf("\n");
    }
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

            Mod_R_M_Result r_m_result = do_mod_r_m(mod, r_m, w);

            u16 data = eat_byte();
            if (w)
                data = data | (eat_byte() << 8);

            printf("mov %s, %s%d\n", r_m_result.string_data, (w) ? "word " : "byte ", data);
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

                Mod_R_M_Result r_m_result = do_mod_r_m(mod, r_m, w);

                s16 data;
                if (!s && w)
                {
                    data = eat_byte();
                    data = data | (eat_byte() << 8);
                }
                else
                    data = (s8)eat_byte();

                if (s)
                    printf("%s %s%s, %d\n", op, (r_m_result.string_data[0] == '[') ? r_m_result.string_size : "", r_m_result.string_data, data);
                else
                    printf("%s %s%s, %u\n", op, (r_m_result.string_data[0] == '[') ? r_m_result.string_size : "", r_m_result.string_data, data);
            }
        }

        else if ((instruction >> 4) == 0b1011)    // mov immediate to register
        {
            u8 w   = (instruction & 0b1000);
            u8 reg = (instruction & 0b0111) | w;

            u16 data = eat_byte();
            if (w)
                data |= eat_byte() << 8;

            printf("mov %s, %d", register_name_table[reg], data);

            auto register_pointer   =  register_pointer_table[reg];
            u16 *dest_register      = &registers[register_pointer.index];
            u16  prev_register_data = *dest_register;

            data <<= register_pointer.shift;
            data  &= register_pointer.mask;
            (*dest_register) &= ~register_pointer.mask;
            (*dest_register) |= data;

            printf("  ; %s:0x%x -> 0x%x\n", register_name_table[reg], prev_register_data, *dest_register);
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
                    data = (s8)eat_byte();
                }


                printf("%s %s, %d\n", op, (w) ? "ax" : "al", data);
            }
        }

        else if ((instruction >> 4) == 0b0111) // jumps
        {
            char *jump_str = 0;
            u8 jump_code = instruction & 0b1111;
                 if (jump_code == 0b0101)
                jump_str = "jne";
            else if (jump_code == 0b0100)
                jump_str = "je";
            else if (jump_code == 0b1100)
                jump_str = "jl";
            else if (jump_code == 0b1110)
                jump_str = "jle";
            else if (jump_code == 0b0010)
                jump_str = "jb";
            else if (jump_code == 0b0110)
                jump_str = "jbe";
            else if (jump_code == 0b1010)
                jump_str = "jp";
            else if (jump_code == 0b0000)
                jump_str = "jo";
            else if (jump_code == 0b1000)
                jump_str = "js";
            else if (jump_code == 0b1101)
                jump_str = "jnl";
            else if (jump_code == 0b1111)
                jump_str = "jg";
            else if (jump_code == 0b0011)
                jump_str = "jnb";
            else if (jump_code == 0b0111)
                jump_str = "ja";
            else if (jump_code == 0b1011)
                jump_str = "jnp";
            else if (jump_code == 0b0001)
                jump_str = "jno";
            else if (jump_code == 0b1001)
                jump_str = "jns";

            if (!jump_str)
            {
                printf("unknown jump instruction: ");
                print_binary(instruction);
                printf("\n");
            }
            else
            {
                s8 ip_inc8 = eat_byte();
                ip_inc8 += 2;
                printf("%s $%+d\n", jump_str, ip_inc8);
            }
        }
        else if ((instruction >> 4) == 0b1110) // loops
        {
            char *loop_str = 0;
            u8 loop_code = instruction & 0b1111;
                 if (loop_code == 0b0010)
                loop_str = "loop";
            else if (loop_code == 0b0001)
                loop_str = "loopz";
            else if (loop_code == 0b0000)
                loop_str = "loopnz";
            else if (loop_code == 0b0011)
                loop_str = "jcxz";

            if (!loop_str)
            {
                printf("unknown loop instruction: ");
                print_binary(instruction);
                printf("\n");
            }
            else
            {
                s8 ip_inc8 = eat_byte();
                ip_inc8 += 2;
                printf("%s $%+d\n", loop_str, ip_inc8);
            }
        }

        else
        {
            printf("unknown: %x    ", instruction);
            print_binary(instruction);
            printf("\n");
        }

    }

    printf("\nFinal registers:\n");
    printf("    ax: 0x%x (%d)\n", registers[ax], registers[ax]);
    printf("    bx: 0x%x (%d)\n", registers[bx], registers[bx]);
    printf("    cx: 0x%x (%d)\n", registers[cx], registers[cx]);
    printf("    dx: 0x%x (%d)\n", registers[dx], registers[dx]);
    printf("    sp: 0x%x (%d)\n", registers[sp], registers[sp]);
    printf("    bp: 0x%x (%d)\n", registers[bp], registers[bp]);
    printf("    si: 0x%x (%d)\n", registers[si], registers[si]);
    printf("    di: 0x%x (%d)\n", registers[di], registers[di]);

    
    return 0;
}

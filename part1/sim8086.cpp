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

char *_register_name_table[] = {
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


enum Register_Index {
    ax,
    bx,
    cx,
    dx,

    sp,
    bp,
    di,
    si,

    ip,

    REGISTER_COUNT,
};

enum Flags {
    CF,
    PF,
    AF,
    ZF,
    SF,
    TF,
    IF,
    DF,
    OF,

    FLAGS_COUNT,
};

static char flag_names[] = {
    'C',
    'P',
    'A',
    'Z',
    'S',
    'T',
    'I',
    'D',
    'O',
};

struct Register_Pointer
{
    Register_Index index;
    u16            mask;
    u16            shift;
    char           name[3];
};

enum Decoded_Op
{
    OP_MOV,
    OP_ADD,
    OP_SUB,
    OP_CMP,

    OP_UNKNOWN,
};

static char *op_names[] = {
    "mov",
    "add",
    "sub",
    "cmp",
    
    "", // OP_UNKNOWN
};

Register_Pointer register_pointer_table[] = {
                               //    W REG/R_M
    { ax, 0x00FF, 0, "al" },   // 0b 0 000
    { cx, 0x00FF, 0, "cl" },   // 0b 0 001
    { dx, 0x00FF, 0, "dl" },   // 0b 0 010
    { bx, 0x00FF, 0, "bl" },   // 0b 0 011
    { ax, 0xFF00, 8, "ah" },   // 0b 0 100
    { cx, 0xFF00, 8, "ch" },   // 0b 0 101
    { dx, 0xFF00, 8, "dh" },   // 0b 0 110
    { bx, 0xFF00, 8, "bh" },   // 0b 0 111

    { ax, 0xFFFF, 0, "ax" },   // 0b 1 000
    { cx, 0xFFFF, 0, "cx" },   // 0b 1 001
    { dx, 0xFFFF, 0, "dx" },   // 0b 1 010
    { bx, 0xFFFF, 0, "bx" },   // 0b 1 011
    { sp, 0xFFFF, 0, "sp" },   // 0b 1 100
    { bp, 0xFFFF, 0, "bp" },   // 0b 1 101
    { si, 0xFFFF, 0, "si" },   // 0b 1 110
    { di, 0xFFFF, 0, "di" },   // 0b 1 111
};

Decoded_Op decode_op(u8 op_code)
{

    if      (op_code == 0)
        return OP_ADD;
    else if (op_code == 0b101)
        return OP_SUB;
    else if (op_code == 0b111)
        return OP_CMP;

    assert(false);
    return OP_UNKNOWN;
}

void fill_flags_string(u16 flags, char out_str[]) {
    if (!flags) {
        out_str[0] = '0';
        out_str[1] =  0;
        return;
    }

    for (int it = 0; it < FLAGS_COUNT; it += 1) {
        if (!(flags & (1 << it)))  continue;
        
        *out_str = flag_names[it];
        out_str += 1;
    }

    *out_str = 0;
}

int first_bit_set_high(u64 value) {
    int bit_index = 0;

    while (value >> bit_index)
        bit_index += 1;

    return bit_index - 1;
}

// =========================================
// State variables
//
static u8 *instruction_pointer;
static u8 *instruction_start;
static u8 *instruction_end;
static u16 registers[REGISTER_COUNT];
static u16 flags_register;

u8 eat_byte()
{
    u8 byte = *instruction_pointer;
    instruction_pointer += 1;
    assert(instruction_pointer <= instruction_end);

    registers[ip] += 1;

    return byte;
};

u8 peek_byte()
{
    return *instruction_pointer;
};

void exec_op(Decoded_Op op, Register_Pointer *dest_reg_ptr, u16 data) {
    u16 *dest_reg          = &registers[  dest_reg_ptr->index];
    u16 prev_register_data = *dest_reg;

    u16 result = ((*dest_reg) >> dest_reg_ptr->shift) & dest_reg_ptr->mask;
    bool do_flags = true;
    u16 prev_flags = flags_register;
    switch(op) {
        case OP_MOV: {
            result = data;
            do_flags = false;
        } break;

        case OP_ADD: result += data; break;
        case OP_SUB:
        case OP_CMP: result -= data; break;
    }
    result <<= dest_reg_ptr->shift;
    result  &= dest_reg_ptr->mask;

    if (op != OP_CMP) {
        (*dest_reg) &= ~dest_reg_ptr->mask;
        (*dest_reg) |= result;
    }

    if (do_flags) {
        auto high_bit = first_bit_set_high(dest_reg_ptr->mask);

        flags_register &= (~(1 << ZF)) & (~(1 << SF));
        flags_register |=  (result == 0)             << ZF;
        flags_register |= ((result >> high_bit) & 1) << SF;
    }

    printf("\t; %s:0x%x -> 0x%x", dest_reg_ptr->name, prev_register_data, *dest_reg);

    printf("\tip:0x%x", registers[ip]);

    if (do_flags) {
        char curr_flags_str[FLAGS_COUNT + 1] = {};
        char prev_flags_str[FLAGS_COUNT + 1] = {};

        fill_flags_string(flags_register, curr_flags_str);
        fill_flags_string(prev_flags, prev_flags_str);
        printf("\tflags: %s -> %s", prev_flags_str, curr_flags_str);
    }
}

void exec_op(Decoded_Op op, Register_Pointer *dest_reg_ptr, Register_Pointer *source_reg_ptr) {
    assert((dest_reg_ptr->mask >> dest_reg_ptr->shift) == (source_reg_ptr->mask >> source_reg_ptr->shift));

    u16 *source_reg = &registers[source_reg_ptr->index];
    u16 data        = ((*source_reg) >> source_reg_ptr->shift) & source_reg_ptr->mask;

    exec_op(op, dest_reg_ptr, data);
}


struct Mod_R_M_Result
{
    bool              is_memory;
    Register_Pointer *register_pointer;

    // @todo: when is_memory == false, string_data = "" and use register_pointer.name
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
        sprintf_s(result.string_data, arr_len(result.string_data), "%s", register_pointer_table[r_m | w].name);
        result.register_pointer = &register_pointer_table[r_m | w];
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
void do_d_w_mod_reg_rm(u8 instruction, Decoded_Op op)
{
    char *op_str = op_names[op];

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
        printf("%s %s, %s", op_str, register_pointer_table[reg].name, r_m_result.string_data);
    else
        printf("%s %s, %s", op_str, r_m_result.string_data, register_pointer_table[reg].name);


    // exec
    if (!r_m_result.is_memory) {
        auto   dest_reg_ptr = d_flag ? &register_pointer_table[reg] :  r_m_result.register_pointer;
        auto source_reg_ptr = d_flag ?  r_m_result.register_pointer : &register_pointer_table[reg];
        exec_op(op, dest_reg_ptr, source_reg_ptr);
    }
    printf("\n");
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
            do_d_w_mod_reg_rm(instruction, OP_MOV);
        }
        else if (((instruction >> 2) & 0b110001) == 0)
        {
            // 0b000000 == add  reg/memory with register to either
            // 0b001010 == sub  reg/memory and register to either
            // 0b001110 == cmp  register/memory and register
            u8   op_code = (instruction >> 3) & 0b111;
            auto op      = decode_op(op_code);

            if (op < OP_UNKNOWN)
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
            u8   op_code = (peek_byte() >> 3) & 0b111;
            auto op      = decode_op(op_code);
            auto op_str  = op_names[op];

            if (op == OP_UNKNOWN)
            {
                printf("unknown op: register/memory to register   --> ");
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

                if (s) // signed
                    printf("%s %s%s, %d", op_str, (r_m_result.is_memory) ? r_m_result.string_size : "", r_m_result.string_data, data);
                else
                    printf("%s %s%s, %u", op_str, (r_m_result.is_memory) ? r_m_result.string_size : "", r_m_result.string_data, data);

                // exec
                if (!r_m_result.is_memory) {
                    auto   dest_reg_ptr = r_m_result.register_pointer;
                    exec_op(op, dest_reg_ptr, data);
                }

                printf("\n");
            }
        }

        else if ((instruction >> 4) == 0b1011)    // mov immediate to register
        {
            u8 w   = (instruction & 0b1000);
            u8 reg = (instruction & 0b0111) | w;

            u16 data = eat_byte();
            if (w)
                data |= eat_byte() << 8;

            auto register_pointer   =  register_pointer_table[reg];
            printf("mov %s, %d", register_pointer.name, data);

            // exec
            u16 *dest_register      = &registers[register_pointer.index];
            u16  prev_register_data = *dest_register;

            data <<= register_pointer.shift;
            data  &= register_pointer.mask;
            (*dest_register) &= ~register_pointer.mask;
            (*dest_register) |= data;

            printf("\t; %s:0x%x -> 0x%x\tip:0x%x\n", register_pointer.name, prev_register_data, *dest_register, registers[ip]);
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
            u8   op_code = (instruction >> 3) & 0b111;
            auto op      = decode_op(op_code);
            auto op_str  = op_names[op];

            if (!op_str)
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


                printf("%s %s, %d\n", op_str, (w) ? "ax" : "al", data);
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

            assert(jump_str);

            s8 ip_inc8 = eat_byte();
            ip_inc8 += 2;
            printf("%s $%+d\n", jump_str, ip_inc8);


            // exec
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

            assert(loop_str);
            s8 ip_inc8 = eat_byte();
            ip_inc8 += 2;
            printf("%s $%+d\n", loop_str, ip_inc8);
        }

        else
        {
            printf("unknown: %x    ", instruction);
            print_binary(instruction);
            printf("\n");
        }

    }

    char final_flags_str[FLAGS_COUNT + 1] = {};
    fill_flags_string(flags_register, final_flags_str);

    printf("\nFinal registers:\n");
    if (registers[ax]) printf("    ax: 0x%04x (%d)\n", registers[ax], registers[ax]);
    if (registers[bx]) printf("    bx: 0x%04x (%d)\n", registers[bx], registers[bx]);
    if (registers[cx]) printf("    cx: 0x%04x (%d)\n", registers[cx], registers[cx]);
    if (registers[dx]) printf("    dx: 0x%04x (%d)\n", registers[dx], registers[dx]);
    if (registers[sp]) printf("    sp: 0x%04x (%d)\n", registers[sp], registers[sp]);
    if (registers[bp]) printf("    bp: 0x%04x (%d)\n", registers[bp], registers[bp]);
    if (registers[si]) printf("    si: 0x%04x (%d)\n", registers[si], registers[si]);
    if (registers[di]) printf("    di: 0x%04x (%d)\n", registers[di], registers[di]);
                       printf("    ip: 0x%04x (%d)\n", registers[ip], registers[ip]);
                       printf(" flags: %s", final_flags_str);

    printf("\n");
    
    return 0;
}

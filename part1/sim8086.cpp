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
#define w_reg_bp 0b1101
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

struct Memory_Pointer {
    Register_Pointer *addend_0;
    Register_Pointer *addend_1;
    s16               address;
    u16               num_bytes;
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
#define MEMORY_SIZE 0xFFFF
static u8  memory[MEMORY_SIZE];
static u8 *instruction_pointer;
static u8 *instruction_start;
static u8 *instruction_end;
static u16 registers[REGISTER_COUNT];
static u16 flags_register;

u16 calc_effective_address(Memory_Pointer *memptr) {
    u64 mem_address = memptr->address;
    if (memptr->addend_0)
        mem_address += registers[memptr->addend_0->index];
    if (memptr->addend_1)
        mem_address += registers[memptr->addend_1->index];

    assert(mem_address <= 0xFFFF);
    return (u16)mem_address;
};

u16 read_memory(Memory_Pointer *memptr) {
    u16 mem_data = 0;

    auto address = calc_effective_address(memptr);
    mem_data = memory[address];
    if (memptr->num_bytes > 1) {
        assert(memptr->num_bytes == 2);
        mem_data |= memory[address + 1] << 8;
    }

    return mem_data;
}


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

void print_op(Decoded_Op op, char *dest_str, u16 curr_data, u16 prev_data, bool print_flags = false, u16 prev_flags = 0) {
    assert(dest_str);

    printf("\t; %s:0x%04x -> 0x%04x", dest_str, prev_data, curr_data);

    printf("\tip:0x%x", registers[ip]);

    if (print_flags) {
        char curr_flags_str[FLAGS_COUNT + 1] = {};
        char prev_flags_str[FLAGS_COUNT + 1] = {};

        fill_flags_string(flags_register, curr_flags_str);
        fill_flags_string(    prev_flags, prev_flags_str);
        printf("\tflags: %s -> %s", prev_flags_str, curr_flags_str);
    }
}

// returns: true if flags were edited
bool exec_op(Decoded_Op op, u16 *dest, u16 dest_shift, u16 dest_mask, u16 data) {
    u16 prev_register_data = *dest;

    u16 result = ((*dest) >> dest_shift) & dest_mask;
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
    result <<= dest_shift;
    result  &= dest_mask;

    if (op != OP_CMP) {
        (*dest) &= ~dest_mask;
        (*dest) |= result;
    }

    if (do_flags) {
        auto high_bit = first_bit_set_high(dest_mask);

        flags_register &= (~(1 << ZF)) & (~(1 << SF));
        flags_register |=  (result == 0)             << ZF;
        flags_register |= ((result >> high_bit) & 1) << SF;
    }

    return do_flags;
}

inline bool exec_op(Decoded_Op op, Register_Pointer *dest_reg_ptr, u16 data) {
    return exec_op(op, &registers[dest_reg_ptr->index], dest_reg_ptr->shift, dest_reg_ptr->mask, data);
}

// returns: true if flags were edited
inline bool exec_op(Decoded_Op op, Register_Pointer *dest_reg_ptr, Register_Pointer *source_reg_ptr) {
    assert((dest_reg_ptr->mask >> dest_reg_ptr->shift) == (source_reg_ptr->mask >> source_reg_ptr->shift));

    u16 *source_reg = &registers[source_reg_ptr->index];
    u16 data        = ((*source_reg) >> source_reg_ptr->shift) & source_reg_ptr->mask;
    return exec_op(op, dest_reg_ptr, data);
}

inline bool exec_op(Decoded_Op op, Memory_Pointer *dest_mem_ptr, u16 data) {
    auto address = calc_effective_address(dest_mem_ptr);
    u16 dest_shift = 0;
    u16 dest_mask  = 0xFF;
    if (dest_mem_ptr->num_bytes > 1)
        dest_mask = 0xFFFF;
    return exec_op(op, (u16 *)&memory[address], dest_shift, dest_mask, data);
}



Memory_Pointer memory_pointer_table[] = {
#define rpt register_pointer_table
#define i_bx 0b1011
#define i_bp 0b1101
#define i_si 0b1110
#define i_di 0b1111
                                 //             REG
    { &rpt[i_bx], &rpt[i_si], }, // "bx + si"   0b 000
    { &rpt[i_bx], &rpt[i_di], }, // "bx + di"   0b 001
    { &rpt[i_bp], &rpt[i_si], }, // "bp + si"   0b 010
    { &rpt[i_bp], &rpt[i_di], }, // "bp + di"   0b 011
    { &rpt[i_si],             }, // "si"        0b 100
    { &rpt[i_di],             }, // "di"        0b 101
    {                         }, // ""          0b 110
    { &rpt[i_bx],             }, // "bx"        0b 111

#undef rpt
#undef i_bx
#undef i_bp
#undef i_si
#undef i_di
};

struct Mod_R_M_Result {
    // @todo: this should probably become a union
    bool              is_memory;
    Register_Pointer *register_pointer;
    Memory_Pointer    memory_pointer;
};

#define arr_len(arr) (sizeof(arr)/sizeof((arr)[0]))
// will advance instruction pointer by calling eat_byte when necessary
Mod_R_M_Result do_mod_r_m(u8 mod, u8 r_m, u8 w)
{
    Mod_R_M_Result result = {};

    w = w << 3;
    if (mod == 0b11)
    {
        result.register_pointer = &register_pointer_table[r_m | w];
    }
    else 
    {
        result.is_memory = true;
        auto *mem_pointer = &result.memory_pointer;
        if ((mod) && (r_m == 0b110))
            mem_pointer->addend_0 = &register_pointer_table[w_reg_bp];
        else
            *mem_pointer = memory_pointer_table[r_m];

        mem_pointer->num_bytes = (w) ? 2 : 1;

        if (mod == 0b01)
        {
            mem_pointer->address = (s8)eat_byte();
        }
        else if ((mod == 0b10) || (r_m == 0b110))
        {
            mem_pointer->address  =  eat_byte();
            mem_pointer->address |= (eat_byte() << 8);
        }
    }

    return result;
}

struct Memory_Pointer_String {
    char data[30];
};
Memory_Pointer_String to_string(Memory_Pointer *memptr) {
    Memory_Pointer_String result = {};

    char *str = result.data;
    auto  len = arr_len(result.data);

    auto advance = sprintf_s(str, len, "%s ", (memptr->num_bytes == 1) ? "byte" : "word");
    str += advance;
    len -= advance;

    advance = sprintf_s(str, len, "[");
    str += advance;
    len -= advance;

    if (memptr->addend_0) {
        advance = sprintf_s(str, len, "%s + ", memptr->addend_0->name);
        str += advance;
        len -= advance;
    }
    if (memptr->addend_1) {
        advance = sprintf_s(str, len, "%s + ", memptr->addend_1->name);
        str += advance;
        len -= advance;
    }

    advance = sprintf_s(str, len, "%d]", memptr->address);
    str += advance;
    len -= advance;

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
    u16   prev_dest     = 0;
    u16   prev_flags    = flags_register;
    u16   curr_data     = 0;
    char *dest_name_str = 0;
    bool flags_edited = false;
    if (!r_m_result.is_memory) {
        auto   dest_reg_ptr = d_flag ? &register_pointer_table[reg] :  r_m_result.register_pointer;
        auto source_reg_ptr = d_flag ?  r_m_result.register_pointer : &register_pointer_table[reg];

        printf("%s %s, %s", op_str, dest_reg_ptr->name, source_reg_ptr->name);

        // exec
        prev_dest    = registers[dest_reg_ptr->index];
        flags_edited = exec_op(op, dest_reg_ptr, source_reg_ptr);

        dest_name_str = dest_reg_ptr->name;
        curr_data     = registers[dest_reg_ptr->index];
    } else {
        auto reg_ptr = &register_pointer_table[reg];

        u16 mem_data = read_memory(&r_m_result.memory_pointer);

        auto mem_string = to_string(&r_m_result.memory_pointer);
        if (d_flag) {
            printf("%s %s, %s", op_str, reg_ptr->name, mem_string.data);

            prev_dest    = registers[reg_ptr->index];
            flags_edited = exec_op(op, reg_ptr, mem_data);

            dest_name_str = reg_ptr->name;
            curr_data     = registers[reg_ptr->index];
        } else {
            printf("%s %s, %s", op_str, mem_string.data, reg_ptr->name);

            u16 data = registers[reg_ptr->index] & reg_ptr->mask;
            data >>= reg_ptr->shift;

            prev_dest    = mem_data;
            flags_edited = exec_op(op, &r_m_result.memory_pointer, data);

            dest_name_str = mem_string.data;
            curr_data     = read_memory(&r_m_result.memory_pointer);
        }

        print_op(op, dest_name_str, curr_data, prev_dest, flags_edited, prev_flags);
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

            if (r_m_result.is_memory) {
                auto mem_string = to_string(&r_m_result.memory_pointer);
                printf("mov %s, %d", mem_string.data, data);

                u16 prev_dest     = read_memory(&r_m_result.memory_pointer);
               exec_op(OP_MOV, &r_m_result.memory_pointer, data);

                print_op(OP_MOV, mem_string.data, read_memory(&r_m_result.memory_pointer), prev_dest, false);
            } else {
                printf("mov %s, %d", r_m_result.register_pointer->name, data);

                u16 prev_dest = registers[r_m_result.register_pointer->index];
                exec_op(OP_MOV, r_m_result.register_pointer, data);

                print_op(OP_MOV, r_m_result.register_pointer->name, registers[r_m_result.register_pointer->index], prev_dest, false);
            }

            printf("\n");
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

                char data_str[30] = {};
                if (s) // signed
                    sprintf_s(data_str, arr_len(data_str), "%d", data);
                else
                    sprintf_s(data_str, arr_len(data_str), "%u", data);



                if (!r_m_result.is_memory) {
                    auto dest_reg_ptr = r_m_result.register_pointer;

                    printf("%s %s, %s", op_str, dest_reg_ptr->name, data_str);

                    // exec
                    u16  prev_dest    = registers[dest_reg_ptr->index];
                    u16  prev_flags   = flags_register;
                    bool flags_edited = exec_op(op, dest_reg_ptr, data);

                    print_op(op, dest_reg_ptr->name, registers[dest_reg_ptr->index], prev_dest, flags_edited, prev_flags);
                }
                else {
                    auto mem_string = to_string(&r_m_result.memory_pointer);

                    printf("%s %s, %s", op_str, mem_string.data, data_str);

                    u16 prev_dest     = read_memory(&r_m_result.memory_pointer);
                    u16  prev_flags   = flags_register;
                    bool flags_edited = exec_op(op, &r_m_result.memory_pointer, data);
                    print_op(op, mem_string.data, read_memory(&r_m_result.memory_pointer), prev_dest, flags_edited, prev_flags);
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

            printf("   \t; %s:0x%04x -> 0x%04x\tip:0x%04x\n", register_pointer.name, prev_register_data, *dest_register, registers[ip]);
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
            char *jump_str  = 0;
            u8    jump_code = instruction & 0b1111;
            bool  condition = false;

            s8 ip_inc8 = eat_byte();

                 if (jump_code == 0b0101) {
                jump_str = "jne";
                condition = !(flags_register & (1 << ZF));
            }
            else if (jump_code == 0b0100) {
                jump_str = "je";
                condition =  (flags_register & (1 << ZF));
            }
            else if (jump_code == 0b1100) {
                jump_str = "jl";
                condition =  (flags_register & ((1 << SF) | (1 << OF)));
            }
            else if (jump_code == 0b1110) {
                jump_str = "jle";
                condition =  (flags_register & (1 << ZF)) || (((flags_register >> SF) ^ (flags_register >> OF)) & 1);
            }
            else if (jump_code == 0b0010) {
                jump_str = "jb";
                condition =  (flags_register & (1 << CF));
            }
            else if (jump_code == 0b0110) {
                jump_str = "jbe";
                condition =  (flags_register & ((1 << CF) | (1 << ZF)));
            }
            else if (jump_code == 0b1010) {
                jump_str = "jp";
                condition =  (flags_register & (1 << PF));
            }
            else if (jump_code == 0b0000) {
                jump_str = "jo";
                condition =  (flags_register & (1 << OF));
            }
            else if (jump_code == 0b1000) {
                jump_str = "js";
                condition =  (flags_register & (1 << SF));
            }
            else if (jump_code == 0b1101) {
                jump_str = "jnl";
                condition = 0 == (((flags_register >> SF) ^ (flags_register >> OF)) & 1);
            }
            else if (jump_code == 0b1111) {
                jump_str = "jg";
                condition =  0 == ( (flags_register & (1 << ZF)) && (((flags_register >> SF) ^ (flags_register >> OF)) & 1) );
            }
            else if (jump_code == 0b0011) {
                jump_str = "jnb";
                condition = 0 == (flags_register & (1 << CF));
            }
            else if (jump_code == 0b0111) {
                jump_str = "ja";
                condition = 0 == (flags_register & ((1 << CF) | (1 << ZF)));
            }
            else if (jump_code == 0b1011) {
                jump_str = "jnp";
                condition = 0 == (flags_register & (1 << PF));
            }
            else if (jump_code == 0b0001) {
                jump_str = "jno";
                condition = 0 == (flags_register & (1 << OF));
            }
            else if (jump_code == 0b1001) {
                jump_str = "jns";
                condition = 0 == (flags_register & (1 << SF));
            }

            assert(jump_str);

            printf("%s $%+d", jump_str, ip_inc8 + 2);

            // exec
            printf("  \t; ip:0x%x\n", registers[ip]);

            if (condition) {
                registers[ip]       += ip_inc8;
                instruction_pointer += ip_inc8;
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

            assert(loop_str);
            s8 ip_inc8 = eat_byte();
            printf("%s $%+d\n", loop_str, ip_inc8 + 2);
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

    printf("\n; Final registers:\n");
    if (registers[ax]) printf(";     ax: 0x%04x (%d)\n", registers[ax], registers[ax]);
    if (registers[bx]) printf(";     bx: 0x%04x (%d)\n", registers[bx], registers[bx]);
    if (registers[cx]) printf(";     cx: 0x%04x (%d)\n", registers[cx], registers[cx]);
    if (registers[dx]) printf(";     dx: 0x%04x (%d)\n", registers[dx], registers[dx]);
    if (registers[sp]) printf(";     sp: 0x%04x (%d)\n", registers[sp], registers[sp]);
    if (registers[bp]) printf(";     bp: 0x%04x (%d)\n", registers[bp], registers[bp]);
    if (registers[si]) printf(";     si: 0x%04x (%d)\n", registers[si], registers[si]);
    if (registers[di]) printf(";     di: 0x%04x (%d)\n", registers[di], registers[di]);
                       printf(";     ip: 0x%04x (%d)\n", registers[ip], registers[ip]);
                       printf(";  flags: %s", final_flags_str);

    printf("\n");
    
    return 0;
}

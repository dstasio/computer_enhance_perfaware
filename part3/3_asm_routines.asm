

global asm_mov_all_bytes
global asm_nop_all_bytes
global asm_cmp_all_bytes
global asm_dec_all_bytes

section .text

asm_mov_all_bytes:
    xor rax, rax
.loop:
    mov byte [rcx + rax*1], al
    inc rax
    cmp rax, rdx
    jl  .loop
    ret


asm_nop_all_bytes:
    xor rax, rax
.loop:
    db 0x0f, 0x1f, 0x00 ; 3-byte NOP
    inc rax
    cmp rax, rdx
    jl  .loop
    ret


asm_cmp_all_bytes:
    xor rax, rax
.loop:
    inc rax
    cmp rax, rdx
    jl  .loop
    ret

asm_dec_all_bytes:
.loop:
    dec rdx
    jnz .loop
    ret


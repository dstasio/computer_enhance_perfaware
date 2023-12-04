

global asm_jump_on_2_loop
global asm_empty_loop

global asm_1x3nop_loop
global asm_3x1nop_loop
global asm_9x1nop_loop
global asm_18x1nop_loop

section .text

asm_empty_loop:
    xor rax, rax
.loop:
    dec rdx
    jnz .loop
    ret

asm_jump_on_2_loop:
    xor rax, rax
.loop:
    mov rcx, 0b1
    and rcx, rdx
    ; jz  .mod2
    inc rax
.mod2:
    dec rdx
    jnz .loop
    ret


asm_1x3nop_loop:
    xor rax, rax
.loop:
    db 0x0f, 0x1f, 0x00 ; 3-byte NOP
    inc rax
    cmp rax, rdx
    jl  .loop
    ret

asm_3x1nop_loop:
    xor rax, rax
.loop:
    nop
    nop
    nop
    inc rax
    cmp rax, rdx
    jl  .loop
    ret

asm_9x1nop_loop:
    xor rax, rax
.loop:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    inc rax
    cmp rax, rdx
    jl  .loop
    ret

asm_18x1nop_loop:
    xor rax, rax
.loop:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    inc rax
    cmp rax, rdx
    jl  .loop
    ret




global asm_jump_on_hit_loop
global asm_jump_on_hit_loop_empty
global asm_jump_on_2_loop
global asm_empty_loop

global asm_1x3nop_loop
global asm_3x1nop_loop
global asm_9x1nop_loop
global asm_18x1nop_loop

section .text

asm_empty_loop:
.loop:
    dec rdx
    jnz .loop
    ret

asm_jump_on_2_loop:
    ; rax: counter of iterations that where not jumped
    ; rcx: buffer pointer; overwritten
    ; rdx: buffer size
    xor rax, rax
.loop:
    mov rcx, 0b1
    and rcx, rdx
    jz  .mod2
    inc rax
.mod2:
    dec rdx
    jnz .loop
    ret

asm_jump_on_hit_loop:
    ; rax: unused
    ; rbx: unused
    ; rcx: buffer pointer; overwritten with current index
    ; rdx: buffer size
    xor rax, rax
    xor rcx, rcx
.loop:
    test al, cl
    jne  .continue
    add rax, 9
.continue:
    inc rcx
    dec rdx
    jnz .loop
    ret

asm_jump_on_hit_loop_empty:
    xor rax, rax
    xor rcx, rcx
.loop:
    test al, cl   ; db 0x66, 0x90, ; 2-byte NOP
    jmp .continue; db 0x66, 0x90 ; 2-byte NOP => jne  .continue
    add rax, 9    ; db 0x0f, 0x1f, 0x40, 0x00 ; 4-byte NOP
.continue:
    inc rcx       ; db 0x0f, 0x1f, 0x00 ; 3-byte NOP
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


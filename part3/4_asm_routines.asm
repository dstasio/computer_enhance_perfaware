
global asm_64_aligned_loop
global asm_3_aligned_loop
global asm_15_aligned_loop
global asm_63_aligned_loop

global asm_empty_loop
;global asm_jump_always_loop
;global asm_jump_mod2_loop
;global asm_jump_mod3_loop
;global asm_jump_mod16_loop

global asm_1x3nop_loop
global asm_3x1nop_loop
global asm_9x1nop_loop
global asm_18x1nop_loop

global read_x1
global read_x2
global read_x3
global read_x4
global read_1x2
global read_8x2

global read_simd_4x2
global read_simd_8x2
global read_simd_16x2
global read_simd_32x2

global write_x1
global write_x2
global write_x3
global write_x4


;
; rcx: buffer pointer
; rdx: buffer size
;

section .text

;
; Execution Ports tests
;
read_x1:
align 64
.loop:
    mov rax, [rcx]
    sub rdx, 1
    jg .loop
    ret

read_x2:
align 64
.loop:
    mov rax, [rcx]
    mov rax, [rcx]
    sub rdx, 2
    jg .loop
    ret

read_x3:
align 64
.loop:
    mov rax, [rcx]
    mov rax, [rcx]
    mov rax, [rcx]
    sub rdx, 3
    jg .loop
    ret

read_x4:
align 64
.loop:
    mov rax, [rcx]
    mov rax, [rcx]
    mov rax, [rcx]
    mov rax, [rcx]
    sub rdx, 4
    jg .loop
    ret

read_1x2:
align 64
.loop:
    mov al, [rcx]
    mov al, [rcx]
    sub rdx, 2
    jg .loop
    ret

read_8x2:
align 64
.loop:
    mov rax, [rcx]
    mov rax, [rcx]
    sub rdx, 2
    jg .loop
    ret

; SIMD reads

read_simd_4x2:
align 64
.loop:
    mov r8d, [rcx]
    mov r8d, [rcx + 4]
    sub rdx, 8
    jg .loop
    ret

read_simd_8x2:
align 64
.loop:
    mov r8, [rcx]
    mov r8, [rcx + 8]
    sub rdx, 16
    jg .loop
    ret

read_simd_16x2:
align 64
.loop:
    vmovdqu xmm0, [rcx]
    vmovdqu xmm1, [rcx + 16]
    sub rdx, 32
    jg .loop
    ret

read_simd_32x2:
align 64
.loop:
    vmovdqu ymm0, [rcx]
    vmovdqu ymm1, [rcx + 32]
    sub rdx, 64
    jg .loop
    ret


write_x1:
align 64
.loop:
    mov [rcx], rax
    sub rdx, 1
    jg .loop
    ret

write_x2:
align 64
.loop:
    mov [rcx], rax
    mov [rcx], rax
    sub rdx, 2
    jg .loop
    ret

write_x3:
align 64
.loop:
    mov [rcx], rax
    mov [rcx], rax
    mov [rcx], rax
    sub rdx, 3
    jg .loop
    ret

write_x4:
align 64
.loop:
    mov [rcx], rax
    mov [rcx], rax
    mov [rcx], rax
    mov [rcx], rax
    sub rdx, 4
    jg .loop
    ret

;
; Code alignment tests
;
asm_64_aligned_loop:
    xor rax, rax
align 64
.loop:
    inc rax
    cmp rax, rdx
    jle .loop
    ret

asm_3_aligned_loop:
    xor rax, rax
align 64
    %rep 3
        nop
    %endrep
.loop:
    inc rax
    cmp rax, rdx
    jle .loop
    ret

asm_15_aligned_loop:
    xor rax, rax
align 64
    %rep 15
        nop
    %endrep
.loop:
    inc rax
    cmp rax, rdx
    jle .loop
    ret

asm_63_aligned_loop:
    xor rax, rax
align 64
    %rep 63
        nop
    %endrep
.loop:
    inc rax
    cmp rax, rdx
    jle .loop
    ret

;
; Branch predictor tests
;

;asm_jump_always_loop:
;asm_jump_mod2_loop:
;asm_jump_mod3_loop:
;asm_jump_mod16_loop:
asm_empty_loop:
.loop:
    dec rdx
    jnz .loop
    ret

;
; Front-end tests: NOPs
;
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


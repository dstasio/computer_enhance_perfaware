
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

;
; Execution ports tests
;   (buffer: *u8, buffer_size: int) -> void
;    rcx: buffer pointer
;    rdx: buffer size
; ---------------------------
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
; Cache tests
;   (buffer: *u8, buffer_size: int, subaddress_mask: u64) -> void
;    rcx: buffer pointer
;    rdx: buffer size
;     r8: subaddress mask
;     r9: 
; ---------------------------
global read_memory_32x2
global read_memory_32x8

;    rcx: buffer pointer
;    rdx: repeat count
;     r8: block size
global read_repeated_memory_block_32x8

;
; Implementations
section .text

read_memory_32x2:
    xor r10, r10 ; r10: offset into memory
align 64
.loop:
    lea r11, [rcx + r10]
    vmovdqu ymm0, [r11]
    vmovdqu ymm0, [r11 + 32]

    add r10, 64
    and r10, r8

    sub rdx, 64
    jg .loop
    ret

read_memory_32x8:
    xor r10, r10 ; r10: offset into memory
    mov r11, rcx ; r11: memory base pointer + offset, recomputed after each iteration
align 64
.loop:
    vmovdqu ymm0, [r11]
    vmovdqu ymm0, [r11 + 32]
    vmovdqu ymm0, [r11 + 64]
    vmovdqu ymm0, [r11 + 96]

    vmovdqu ymm0, [r11 + 128]
    vmovdqu ymm0, [r11 + 160]
    vmovdqu ymm0, [r11 + 192]
    vmovdqu ymm0, [r11 + 224]

    add r10, 0x100 ; 256
    and r10, r8
    lea r11, [rcx + r10]

    sub rdx, 256
    jg .loop
    ret

;    rcx: buffer pointer
;    rdx: block size
;     r8: repeat count
read_repeated_memory_block_32x8:
    xor rax, rax   ; rax: repeat index
align 64
.outer_loop:
    xor r10, r10   ; r10: offset into memory
    mov r11, rcx   ; r11: memory base pointer + offset, recomputed after each iteration
    mov  r9, rdx   ;  r9: remaining byetes to be read in memory block
.inner_loop:
    vmovdqu ymm0, [r11]
    vmovdqu ymm0, [r11 + 32]
    vmovdqu ymm0, [r11 + 64]
    vmovdqu ymm0, [r11 + 96]

    vmovdqu ymm0, [r11 + 128]
    vmovdqu ymm0, [r11 + 160]
    vmovdqu ymm0, [r11 + 192]
    vmovdqu ymm0, [r11 + 224]

    add r10, 0x100 ; 256
    lea r11, [rcx + r10]

    sub r9, 256
    jg .inner_loop

    inc rax
    cmp rax, r8
    jl .outer_loop

    ret



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


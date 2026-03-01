# ===========================================================================
# RISC-V RV32I Startup Code
# Description: Minimal crt0 — sets up stack pointer and jumps to main().
# ===========================================================================

    .section .text.init
    .global _start
    .type   _start, @function

_start:
    # ---- Set stack pointer to top of RAM (8KB = 0x2000) ----
    li  sp, 0x00002000

    # ---- Clear BSS ----
    la  t0, _bss_start
    la  t1, _bss_end
1:
    bge t0, t1, 2f
    sw  zero, 0(t0)
    addi t0, t0, 4
    j   1b
2:

    # ---- Call main() ----
    jal ra, main

    # ---- Infinite loop if main returns ----
_halt:
    j   _halt

    .size _start, . - _start

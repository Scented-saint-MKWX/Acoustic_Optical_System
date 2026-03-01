/* ==========================================================================
 * RISC-V Linker Script for Acoustic-Optical SoC
 * Memory: 8 KB Block RAM at 0x00000000
 * ========================================================================== */

ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 8K
}

SECTIONS
{
    .text : {
        *(.text.init)       /* Startup code first */
        *(.text .text.*)
    } > RAM

    .rodata : {
        *(.rodata .rodata.*)
    } > RAM

    .data : {
        *(.data .data.*)
    } > RAM

    .bss : {
        _bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        _bss_end = .;
    } > RAM

    /* Stack grows downward from top of RAM */
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}

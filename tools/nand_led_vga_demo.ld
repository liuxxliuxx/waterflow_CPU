OUTPUT_ARCH(loongarch)
ENTRY(_start)

/* The NAND hardware loader copies page 0 directly to this reset address. */
MEMORY
{
    DDR (rwx) : ORIGIN = 0x1c000000, LENGTH = 16M
}

SECTIONS
{
    . = ORIGIN(DDR);

    .text : ALIGN(4)
    {
        KEEP(*(.text.start))
        *(.text .text.*)
    } > DDR

    .rodata : ALIGN(4)
    {
        *(.rodata .rodata.*)
    } > DDR

    .data : ALIGN(4)
    {
        *(.data .data.*)
        *(.sdata .sdata.*)
    } > DDR

    . = ALIGN(4);
    __bss_start = .;
    .bss (NOLOAD) : ALIGN(4)
    {
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
    } > DDR
    . = ALIGN(4);
    __bss_end = .;

    PROVIDE(__stack_top = 0x1cfff000);

    /DISCARD/ :
    {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}

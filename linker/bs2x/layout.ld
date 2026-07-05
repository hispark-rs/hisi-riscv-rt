/*
 * Linker script for HiSilicon BS21 / BS2X (RISC-V RV32IMFC).
 *
 * This is a BS2X adapter layout for the legacy hisi-riscv-rt startup path. It
 * keeps the same symbol contract as the WS63 layout because startup.S and the
 * Rust relocation code still consume those names, but it removes WS63-only SRAM
 * reservations such as Wi-Fi packet RAM.
 */

OUTPUT_ARCH("riscv")
ENTRY(reset_vector)

EXTERN(reset_vector)
EXTERN(trap_vector)
EXTERN(trap_entry)
EXTERN(nmi_vector)
EXTERN(runtime_init)
EXTERN(main)

SECTIONS
{
    /* ITCM sections. */
    .patch ORIGIN(ITCM) (NOLOAD) : ALIGN(8) {
        __rom_patch_load__ = LOADADDR(.patch);
        __rom_patch_begin__ = .;
        KEEP(*(.patch_remap))
        KEEP(*(.patch_cmp))
    } > ITCM AT > PROGRAM

    .rom_ram_cb_text : ALIGN(8) {
        __rom_patch_end__ = .;
    } > ITCM AT > PROGRAM

    .text_tcm : ALIGN(8) {
        __tcm_text_load__ = LOADADDR(.text_tcm);
        __tcm_text_begin__ = .;
        *(.text.tcm .text.tcm.*)
        *(.rodata.tcm .rodata.tcm.*)
        . = ALIGN(4);
        __tcm_text_end__ = .;
    } > ITCM AT > PROGRAM

    /* DTCM sections. */
    .rom_data ORIGIN(DTCM) : ALIGN(8) {
        __rom_data_load__ = LOADADDR(.rom_data);
        __rom_data_begin__ = .;
        *(.rom_data .rom_data.*)
        . = ALIGN(4);
    } > DTCM AT > PROGRAM

    .rom_bss (NOLOAD) : ALIGN(8) {
        __rom_bss_begin__ = .;
        *(.rom_bss .rom_bss.*)
        . = ALIGN(4);
        __rom_bss_end__ = .;
    } > DTCM

    .data_tcm : ALIGN(8) {
        __tcm_data_load__ = LOADADDR(.data_tcm);
        __tcm_data_begin__ = .;
        *(.data.tcm .data.tcm.*)
        . = ALIGN(4);
    } > DTCM AT > PROGRAM

    .bss_tcm (NOLOAD) : ALIGN(8) {
        __tcm_bss_begin__ = .;
        *(.bss.tcm .bss.tcm.*)
        . = ALIGN(4);
        __tcm_data_end__ = .;
        __tcm_bss_end__ = .;
    } > DTCM

    __rom_data_end__ = __rom_data_begin__ + SIZEOF(.rom_data);

    /* SRAM text. BS2X has no WS63 Wi-Fi packet RAM reservation here. */
    .text_sram ORIGIN(SRAM) : ALIGN(8) {
        __sram_text_load__ = LOADADDR(.text_sram);
        __sram_text_begin__ = .;
        *(.text.sram .text.sram.*)
        KEEP(*(.patch.text.on.sram .patch.rodata.on.sram))
        . = ALIGN(4);
        __sram_text_end__ = .;
    } > SRAM AT > PROGRAM

    /* Program entry section. */
    .startup ORIGIN(PROGRAM) : ALIGN(8) {
        KEEP(*(.text.entry))
        KEEP(*(.text.runtime.init))
        . = ALIGN(4);
    } > PROGRAM

    .trap : ALIGN(64) {
        __trap_vector_base__ = .;
        KEEP(*(.trap))
        KEEP(*(.trap.exception .trap.exception.*))
        KEEP(*(.trap.nmi))
        KEEP(*(.trap.mie0 .trap.mie1 .trap.mie2 .trap.mie3 .trap.mie4 .trap.mie5))
        KEEP(*(.trap.local))
        KEEP(*(.trap.*))
        . = ALIGN(4);
    } > PROGRAM

    .text : ALIGN(8) {
        *(.text .text.*)
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
        . = ALIGN(8);
        __init_array_start = .;
        KEEP(*(.init_array .init_array.*))
        __init_array_end = .;
        __fini_array_start = .;
        KEEP(*(.fini_array .fini_array.*))
        __fini_array_end = .;
        . = ALIGN(8);
    } > PROGRAM

    .data : ALIGN(8) {
        __data_load__ = LOADADDR(.data);
        __data_begin__ = .;
        __sidata = __data_load__;
        __sdata = .;
        *(.data .data.*)
        *(.got .got.*)
        *(.igot .igot.*)
        _gp_ = . + 0x800;
        *(.sdata .sdata.*)
        . = ALIGN(4);
        __data_end__ = .;
        __edata = .;
    } > SRAM AT > PROGRAM

    .bss (NOLOAD) : ALIGN(8) {
        __bss_begin__ = .;
        __sbss = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end__ = .;
        __ebss = .;
    } > SRAM

    .preserve ORIGIN(PRESERVE) (NOLOAD) : ALIGN(8) {
        KEEP(*(.preserve))
    } > PRESERVE

    .stacks (NOLOAD) : ALIGN(16) {
        __stack_start__ = .;
        . = . + __stack_size;
        . = ALIGN(16);
        __stack_top__ = .;
        _stack_start = __stack_top__;
        _max_hart_id = 0;
        _hart_stack_size = __stack_size;

        __irq_stack_start__ = .;
        . = . + __irq_stack_size;
        . = ALIGN(16);
        __irq_stack_top__ = .;

        __exc_stack_start__ = .;
        . = . + __exc_stack_size;
        . = ALIGN(16);
        __exc_stack_top__ = .;

        __nmi_stack_start__ = .;
        . = . + __nmi_stack_size;
        . = ALIGN(16);
        __nmi_stack_top__ = .;
    } > SRAM

    .heap (NOLOAD) : ALIGN(8) {
        __heap_start__ = .;
        PROVIDE(g_intheap_begin = .);
        PROVIDE(g_intheap_size = ORIGIN(SRAM) + LENGTH(SRAM) - g_intheap_begin);
    } > SRAM
}

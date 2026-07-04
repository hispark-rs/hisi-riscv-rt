/*
 * Linker script for HiSilicon WS63 (RISC-V RV32IMFC)
 *
 * Adapted from the fbb_ws63 SDK linker.prelds for bare-metal Rust.
 *
 * Section layout (simplified from original):
 *   ITCM:  patch tables, rom-ram-cb, TCM text
 *   DTCM:  ROM data, ROM BSS, TCM data, TCM BSS
 *   SRAM:  SRAM text, .data, .bss, stacks, heap
 *   FLASH: .text, .rodata, all initialized data LMA
 *
 * Variables for runtime relocation:
 *   __xxx_load__ = LMA (flash load address)
 *   __xxx_begin__ = VMA start
 *   __xxx_end__ = VMA end
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
    /* ================================================================
     *  ITCM sections (Instruction TCM)
     *  Address: 0x14C000
     *  Contains: patch tables, ROM veneer callbacks, TCM text
     * ================================================================ */

    /* Patch table (ROM function patch redirection) */
    .patch ORIGIN(ITCM) (NOLOAD) : ALIGN(8) {
        __rom_patch_load__ = LOADADDR(.patch);
        __rom_patch_begin__ = .;
        KEEP(*(.patch_remap))
        KEEP(*(.patch_cmp))
    } > ITCM AT > PROGRAM

    /* ROM RAM callback veneers (ROM→RAM jump trampolines) */
    .rom_ram_cb_text : ALIGN(8) {
        __rom_patch_end__ = .;
    } > ITCM AT > PROGRAM

    /* TCM text (hot code placed in fast ITCM) */
    .text_tcm : ALIGN(8) {
        __tcm_text_load__ = LOADADDR(.text_tcm);
        __tcm_text_begin__ = .;
        *(.text.tcm .text.tcm.*)
        *(.rodata.tcm .rodata.tcm.*)
        . = ALIGN(4);
        __tcm_text_end__ = .;
    } > ITCM AT > PROGRAM

    /* ================================================================
     *  DTCM sections (Data TCM)
     *  Address: 0x180000
     *  Contains: ROM data/BSS, TCM data/BSS
     * ================================================================ */

    /* ROM data (copied from flash to DTCM by runtime_init) */
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

    /* TCM data (copied from flash to DTCM by runtime_init) */
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

    /* End of DTCM definitions */
    __rom_data_end__ = __rom_data_begin__ + SIZEOF(.rom_data);

    /* ================================================================
     *  SRAM sections (Main system RAM at 0xA00000)
     *  Contains: SRAM text, .data, .bss, stacks, heap
     * ================================================================ */

    /* WiFi packet RAM reserve (48KB at start of SRAM) */
    PROVIDE(__wifi_pkt_ram_start = ORIGIN(SRAM));
    PROVIDE(__wifi_pkt_ram_size = 0xC000);    /* 48KB */
    PROVIDE(__wifi_pkt_ram_end = __wifi_pkt_ram_start + __wifi_pkt_ram_size);

    /* SRAM text (code copied from flash to SRAM for faster execution) */
    .text_sram __wifi_pkt_ram_end : ALIGN(8) {
        __sram_text_load__ = LOADADDR(.text_sram);
        __sram_text_begin__ = .;
        *(.text.sram .text.sram.*)
        KEEP(*(.patch.text.on.sram .patch.rodata.on.sram))
        . = ALIGN(4);
        __sram_text_end__ = .;
    } > SRAM AT > PROGRAM

    /* ================================================================
     *  FLASH sections (PROGRAM region at 0x230300)
     *  Contains: .text, .rodata, initialization data LMA
     * ================================================================ */

    /* Program entry section (must be first in PROGRAM) */
    .startup ORIGIN(PROGRAM) : ALIGN(8) {
        KEEP(*(.text.entry))
        KEEP(*(.text.runtime.init))
        . = ALIGN(4);
    } > PROGRAM

    /* Trap vector table + handlers. Placed explicitly (KEEP) so the vectored
       table base is deterministically 64-byte aligned (mtvec is set to this base
       in vectored mode — see asm/ws63/startup.S) and the per-entry `j` trampolines
       stay contiguous + in range. Previously these were orphan sections, which
       was fragile (alignment/range) and let --gc-sections drop the trampolines
       and the trap-stack-top symbol references. `.trap` (the table) must be first. */
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

    /* Flash text (main code executing from flash / XIP) */
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

    /* ================================================================
     *  SRAM writable sections (.data, .bss, stacks, heap)
     * ================================================================ */

    /* Initialized data (copied from flash to SRAM) */
    .data : ALIGN(8) {
        __data_load__ = LOADADDR(.data);
        __data_begin__ = .;
        /* riscv-rt v0.14 .data symbols */
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

    /* BSS (zeroed at startup) */
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

    /* ================================================================
     *  Stack sections (NOLOAD, at high SRAM addresses)
     * ================================================================ */

    /* Preserved memory for boot state sharing */
    .preserve ORIGIN(PRESERVE) (NOLOAD) : ALIGN(8) {
        KEEP(*(.preserve))
    } > PRESERVE

    /* Stacks grow downward from the preserved region */
    .stacks (NOLOAD) : ALIGN(16) {
        __stack_start__ = .;
        . = . + __stack_size;          /* User/main stack */
        . = ALIGN(16);
        __stack_top__ = .;
        /* riscv-rt v0.14 stack symbols (must be inside section for visibility) */
        _stack_start = __stack_top__;
        _max_hart_id = 0;
        _hart_stack_size = __stack_size;

        /* IRQ / exception / NMI stacks, carved downward from here (between the
           user stack and the heap). The *_stack_top__ symbols (used by the trap
           handlers in asm/ws63/startup.S, which switch sp to them) are defined HERE as
           the single source of truth — they survive --gc-sections because the
           KEEP'd .trap handlers reference them. The earlier top-of-SRAM fallbacks
           in memory.x were removed: they pointed into the .heap region (a latent
           trap-stack/heap overlap). Each stack grows down from its *_top__. */
        __irq_stack_start__ = .;
        . = . + __irq_stack_size;       /* IRQ stack */
        . = ALIGN(16);
        __irq_stack_top__ = .;

        __exc_stack_start__ = .;
        . = . + __exc_stack_size;       /* Exception stack */
        . = ALIGN(16);
        __exc_stack_top__ = .;

        __nmi_stack_start__ = .;
        . = . + __nmi_stack_size;       /* NMI stack */
        . = ALIGN(16);
        __nmi_stack_top__ = .;
    } > SRAM

    /* Heap uses remaining SRAM */
    .heap (NOLOAD) : ALIGN(8) {
        __heap_start__ = .;
        PROVIDE(g_intheap_begin = .);
        PROVIDE(g_intheap_size = ORIGIN(SRAM) + LENGTH(SRAM) - g_intheap_begin);
    } > SRAM
}

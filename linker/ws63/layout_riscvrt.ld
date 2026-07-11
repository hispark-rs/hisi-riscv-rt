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
ENTRY(_start)

EXTERN(_start)
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

    /* ================================================================
     *  DTCM sections (Data TCM)
     *  Address: 0x180000
     *  Contains: ROM data/BSS, TCM data/BSS
     * ================================================================ */

    /* Mask-ROM BSS addresses are part of the silicon ABI, not inferred from
       linked input sections. In particular, the FRW callback table lives at
       0x181008 and must start zeroed on every application boot. */
    .rom_bss 0x1803e0 (NOLOAD) : AT(0x1803e0) {
        __rom_bss_begin__ = .;
        *(.rom_bss .rom_bss.*)
        . = 0x182888;
        __rom_bss_end__ = .;
    } > DTCM

    ASSERT(__rom_bss_begin__ == 0x1803e0 && __rom_bss_end__ == 0x182888,
           "WS63 mask-ROM BSS ABI range drifted")

    /* ================================================================
     *  SRAM sections (Main system RAM at 0xA00000)
     *  Contains: SRAM text, .data, .bss, stacks, heap
     * ================================================================ */

    /* Wi-Fi packet RAM reserve (48KB at start of SRAM).
       The vendor RF blobs reference the double-underscore begin/end symbols.
       Model this as a real NOLOAD section instead of example-local --defsym
       glue so the SRAM layout has one owner. */
    .wifi_pkt_ram ORIGIN(SRAM) (NOLOAD) : AT(ORIGIN(SRAM)) {
        . = ALIGN(8);
        __wifi_pkt_ram_begin__ = .;
        . = . + 0xC000;
        . = ALIGN(8);
        __wifi_pkt_ram_end__ = .;
    } > SRAM
    PROVIDE(__wifi_pkt_ram_start = __wifi_pkt_ram_begin__);
    PROVIDE(__wifi_pkt_ram_end = __wifi_pkt_ram_end__);
    PROVIDE(__wifi_pkt_ram_size = SIZEOF(.wifi_pkt_ram));

    /* ================================================================
     *  FLASH sections (PROGRAM region at 0x230300)
     *  Contains: .text, .rodata, initialization data LMA
     * ================================================================ */

    /* Program entry section (must be first in PROGRAM).
       riscv-rt-start-experiment: .init contains riscv-rt's _start.
       Default path: .text.entry contains our reset_vector. */
    .startup ORIGIN(PROGRAM) : ALIGN(8) {
        KEEP(*(.init))
        KEEP(*(.init.trap))
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
        KEEP(*(.patch.text.on.flash .patch.rodata.on.flash))
        *(.wifi.tcm.text .wifi.tcm.text.*)
        *(.wifi.tcm.rodata .wifi.tcm.rodata.*)
        . = ALIGN(8);
        __init_array_start = .;
        KEEP(*(.init_array .init_array.*))
        __init_array_end = .;
        __fini_array_start = .;
        KEEP(*(.fini_array .fini_array.*))
        __fini_array_end = .;
        . = ALIGN(8);
    } > PROGRAM

    /* Loadable mask-ROM patch table, generated against this final ELF. */
    .patch ORIGIN(ITCM) : ALIGN(8) {
        FILL(0x00)
        __rom_patch_load__ = LOADADDR(.patch);
        __rom_patch_begin__ = .;
        KEEP(*(.patch_remap))
        . = ORIGIN(ITCM) + 0x610;
        __rom_patch_cmp_begin__ = .;
        KEEP(*(.patch_cmp))
        . = ORIGIN(ITCM) + 0x928;
        __rom_patch_end__ = .;
    } > ITCM AT > PROGRAM

    ASSERT(__rom_patch_begin__ == 0x14c000 &&
           __rom_patch_cmp_begin__ == 0x14c610 &&
           __rom_patch_end__ == 0x14c928,
           "WS63 ROM patch ABI prefix has the wrong layout")

    .data_tcm : ALIGN(8) {
        __tcm_data_load__ = LOADADDR(.data_tcm);
        __tcm_data_begin__ = .;
        *(.data.tcm .data.tcm.*)
        KEEP(*(.patch.data.on.itcm))
        . = ALIGN(4);
    } > DTCM AT > PROGRAM

    .bss_tcm (NOLOAD) : AT(.) {
        . = ALIGN(8);
        __tcm_bss_begin__ = .;
        *(.bss.tcm .bss.tcm.*)
        KEEP(*(.patch.bss.on.itcm))
        . = ALIGN(4);
        __tcm_data_end__ = .;
        __tcm_bss_end__ = .;
    } > DTCM

    .text_sram __wifi_pkt_ram_end__ : ALIGN(8) {
        __sram_text_load__ = LOADADDR(.text_sram);
        __sram_text_begin__ = .;
        *(.text.sram .text.sram.*)
        KEEP(*(.patch.text.on.sram .patch.rodata.on.sram))
        . = ALIGN(4);
        __sram_text_end__ = .;
    } > SRAM AT > PROGRAM

    /* ROM data runs from its fixed DTCM ABI but is loaded after flash text. */
    .rom_data ORIGIN(DTCM) : ALIGN(8) {
        __rom_data_load__ = LOADADDR(.rom_data);
        __rom_data_begin__ = .;
        KEEP(*(.data.g_sfc_v150_funcs))
        KEEP(*(.data.g_hal_pin_ws63_funcs))
        KEEP(*(.data.g_hal_watchdog_v151_funcs))
        KEEP(*(.data.g_watchdog_base_addr))
        KEEP(*(.data.g_watchdog_clock))
        KEEP(*(.data.g_hal_timer_v150_funcs))
        KEEP(*(.data.g_timer_clock_value))
        KEEP(*(.data.g_hal_systick_ws63_funcs))
        KEEP(*(.data.g_systick_clock))
        KEEP(*(.data.strNullPointer))
        KEEP(*(.data.strNullString))
        KEEP(*(.data.wStrNullString))
        KEEP(*(.data.g_hal_tcxo_v150_funcs))
        KEEP(*(.data.g_tcxo_ticks_per_usec))
        *(.rom_data .rom_data.*)
        . = ALIGN(4);
        __rom_data_end__ = .;
    } > DTCM AT > PROGRAM
    ASSERT(!DEFINED(g_systick_clock) || g_systick_clock == 0x180090,
           "WS63 platform ROM-data order drifted at g_systick_clock")
    ASSERT(!DEFINED(g_tcxo_ticks_per_usec) || g_tcxo_ticks_per_usec == 0x1800d0,
           "WS63 platform ROM-data order drifted at g_tcxo_ticks_per_usec")

    /* Define ITCM-loaded sections only after the flash text so their LMAs do
       not collide with the explicit PROGRAM entry at 0x230300. */
    .rom_ram_cb_text (ORIGIN(ITCM) + 0x928) : ALIGN(8) {
        __tcm_text_load__ = LOADADDR(.rom_ram_cb_text);
        __tcm_text_begin__ = .;
        KEEP(*(.*.romcall.text))
    } > ITCM AT > PROGRAM

    .text_tcm : ALIGN(8) {
        *(.text.tcm .text.tcm.*)
        *(.rodata.tcm .rodata.tcm.*)
        KEEP(*(.patch.text.on.itcm .patch.rodata.on.itcm))
        . = ALIGN(4);
        __tcm_text_end__ = .;
    } > ITCM AT > PROGRAM

    ASSERT(!DEFINED(__wrap_log_event_wifi_print1) ||
           __wrap_log_event_wifi_print1 == 0x14ce28,
           "WS63 ROM callback veneer order/address drifted")

    /* ================================================================
     *  SRAM writable sections (.data, .bss, stacks, heap)
     * ================================================================ */

    /* Initialized data (copied from flash to SRAM) */
    /* Capture the ABI-fixed Wi-Fi ROM globals before generic .data. */
    .wifi_rom_data (ORIGIN(DTCM) + 0xd8) : ALIGN(1) {
        __wifi_rom_data_load__ = LOADADDR(.wifi_rom_data);
        __wifi_rom_data_begin__ = .;
        KEEP(*(.data.g_ltf_and_gi))
        . += 2;
        KEEP(*(.data.g_11b_per_cnt))
        KEEP(*(.data.g_dmac_algorithm_main))
        KEEP(*(.data.g_temp_protect_aggr_max_mpdu))
        KEEP(*(.data.g_btcoex_aggr_max_mpdu))
        KEEP(*(.data.g_smooth_phase))
        KEEP(*(.data.g_rf_switch_cfg))
        KEEP(*(.data.g_mac_pa_switch))
        . += 3;
        KEEP(*(.data.g_hal_cfg_custom))
        KEEP(*(.data.g_mac_res))
        KEEP(*(.data.g_buf_size))
        . += 2;
        KEEP(*(.data.g_mem_start_addr_cfg))
        KEEP(*(.data.g_skb_size))
        __wifi_rom_data_end__ = .;
    } > DTCM AT > PROGRAM

    ASSERT(SIZEOF(.rom_data) <= 0xd8,
           "platform ROM data overlaps the WS63 Wi-Fi ROM-data ABI window")
    ASSERT(!DEFINED(g_rf_switch_cfg) || g_rf_switch_cfg == 0x1800eb,
           "WS63 g_rf_switch_cfg address drifted from the mask-ROM ABI")

    .data : ALIGN(8) {
        __data_load__ = LOADADDR(.data);
        __data_begin__ = .;
        /* riscv-rt v0.14 .data symbols */
        __sidata = __data_load__;
        __sdata = .;
        *(.data .data.*)
        KEEP(*(.patch.data.on.sram))
        *(.wifi.tcm.data .wifi.tcm.data.*)
        *(.got .got.*)
        *(.igot .igot.*)
        _gp_ = . + 0x800;
        PROVIDE(__global_pointer$ = _gp_);
        *(.sdata .sdata.*)
        . = ALIGN(4);
        __data_end__ = .;
        __edata = .;
    } > SRAM AT > PROGRAM

    /* BSS (zeroed at startup) */
    .bss (NOLOAD) : AT(.) {
        . = ALIGN(8);
        __bss_begin__ = .;
        __sbss = .;
        *(.bss .bss.*)
        KEEP(*(.patch.bss.on.sram))
        *(.sbss .sbss.*)
        *(.wifi.tcm.bss .wifi.tcm.bss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end__ = .;
        __ebss = .;
    } > SRAM

    /* ================================================================
     *  Stack sections (NOLOAD, at high SRAM addresses)
     * ================================================================ */

    /* Preserved memory for boot state sharing */
    .preserve ORIGIN(PRESERVE) (NOLOAD) : AT(ORIGIN(PRESERVE)) {
        . = ALIGN(8);
        KEEP(*(.preserve))
    } > PRESERVE

    /* Stacks grow downward from the preserved region */
    .stacks (NOLOAD) : AT(.) {
        . = ALIGN(16);
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
    .heap (NOLOAD) : AT(.) {
        . = ALIGN(8);
        __heap_start__ = .;
        PROVIDE(g_intheap_begin = .);
        __heap_end__ = ORIGIN(PRESERVE);
        PROVIDE(g_intheap_size = __heap_end__ - g_intheap_begin);
    } > SRAM

    ASSERT(__heap_start__ <= __heap_end__, "WS63 SRAM overflow: no room remains for heap")
}

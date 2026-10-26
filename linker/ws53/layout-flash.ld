OUTPUT_ARCH("riscv")
ENTRY(reset_vector)
EXTERN(reset_vector runtime_init main __INTERRUPTS __hisi_ws53_prepare_flash_ram)
PROVIDE(WS53_NMI = __ws53_default_nmi);
SECTIONS {
    .startup ORIGIN(PROGRAM) : ALIGN(4) { KEEP(*(.text.entry)) } > PROGRAM
    .trap : ALIGN(256) { KEEP(*(.trap .trap.*)) } > PROGRAM
    .text : ALIGN(4) { *(.text .text.*) } > PROGRAM
    .rodata : ALIGN(4) { *(.rodata .rodata.* .srodata .srodata.*) } > PROGRAM
    .data : ALIGN(8) {
        __data_begin__ = .;
        *(.data .data.* .sdata .sdata.*);
        _gp_ = __data_begin__ + 0x800;
        . = ALIGN(4); __data_end__ = .;
    } > SRAM AT > PROGRAM
    __data_load__ = LOADADDR(.data);
    __flash_image_end__ = LOADADDR(.data) + SIZEOF(.data);
    .bss (NOLOAD) : ALIGN(8) {
        __bss_begin__ = .;
        *(.bss .bss.* .sbss .sbss.* COMMON);
        . = ALIGN(4); __bss_end__ = .;
    } > SRAM
    .stacks (NOLOAD) : ALIGN(16) {
        __stack_start__ = .; . += __stack_size; __stack_top__ = .;
        . = ALIGN(16); __irq_stack_start__ = .; . += __irq_stack_size; __irq_stack_top__ = .;
        . = ALIGN(16); __exc_stack_start__ = .; . += __exc_stack_size; __exc_stack_top__ = .;
        . = ALIGN(16); __nmi_stack_start__ = .; . += __nmi_stack_size; __nmi_stack_top__ = .;
    } > SRAM
    .bootstrap_stack (NOLOAD) : ALIGN(16) {
        __bootstrap_stack_bottom__ = .;
        . += LENGTH(BOOTSTRAP);
        __bootstrap_stack_top__ = .;
    } > BOOTSTRAP
    /DISCARD/ : { *(.eh_frame .eh_frame_hdr) }
}
ASSERT(ORIGIN(PROGRAM) == 0x45D300, "WS53 vendor application entry mismatch")
ASSERT((__hisi_ws53_early_trap_vector & 255) == 0,
       "WS53 early trap vector must be 256-byte aligned")
ASSERT((trap_vector & 255) == 0, "WS53 trap vector must be 256-byte aligned")
ASSERT(__flash_image_end__ <= 0x670000, "WS53 application partition overflow")
ASSERT(__bootstrap_stack_bottom__ == 0x2F000 && __bootstrap_stack_top__ == 0x30000,
       "WS53 bootstrap must remain in ITCM banks0/1")
ASSERT(__data_begin__ >= 0x20010000 && __nmi_stack_top__ <= 0x2005FF00,
       "WS53 application RAM overlaps control/shared/preserved memory")
ASSERT(__nmi_stack_top__ <= ORIGIN(SRAM) + LENGTH(SRAM), "WS53 RAM/stack overflow")

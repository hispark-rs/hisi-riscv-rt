OUTPUT_ARCH("riscv")
ENTRY(reset_vector)
EXTERN(reset_vector runtime_init main __INTERRUPTS)
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
    } > SRAM
    __data_load__ = LOADADDR(.data);
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
    /DISCARD/ : { *(.eh_frame .eh_frame_hdr) }
}
ASSERT(__nmi_stack_top__ <= ORIGIN(SRAM) + LENGTH(SRAM), "WS53 RAM/stack overflow")

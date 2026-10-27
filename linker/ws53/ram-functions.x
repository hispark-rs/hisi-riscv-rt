/* MCU_MODE_1 Acore banks0/1, below the live bootstrap stack. No extra banks,
 * control-core memory or shared buffers are allocated by this feature.
 * Keep load bytes in PROGRAM: FlashBoot never loads this VMA itself.
 */
MEMORY { RAM_FUNCTIONS (rx) : ORIGIN = 0x28000, LENGTH = 0x7000 }
/* riscv-rt contributes .init even with our custom entry. Without explicit
 * placement LLD may orphan it next to the new low-address executable section,
 * making its JAL references to main/abort exceed their architectural range.
 */
SECTIONS {
    .ws53.flash_init : { *(.init .init.*) } > PROGRAM
} INSERT BEFORE .rodata;
SECTIONS {
    .ws53.ramtext : ALIGN(32) {
        __ws53_ramtext_begin = .;
        KEEP(*(.ws53.ramtext .ws53.ramtext.*))
        KEEP(*(.ws53.ramrodata .ws53.ramrodata.*))
        . = ALIGN(4);
        __ws53_ramtext_end = .;
    } > RAM_FUNCTIONS AT > PROGRAM
    __ws53_ramtext_load = LOADADDR(.ws53.ramtext);
} INSERT AFTER .rodata;
ASSERT(__ws53_ramtext_begin >= 0x28000 && __ws53_ramtext_end <= 0x2f000,
       "WS53 RAM functions overlap bootstrap or unowned memory")
ASSERT(__ws53_ramtext_load >= 0x45d300 &&
       __ws53_ramtext_load + SIZEOF(.ws53.ramtext) <= __data_load__,
       "WS53 RAM functions require a distinct Flash LMA before data")

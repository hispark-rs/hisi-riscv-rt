/* WS53 Acore MCU_MODE_1 RAM-debug profile. No flash load segments.
 * Uses upper 32 KiB of application ITCM and upper 64 KiB of application DTCM.
 * The debugger must halt Acore and verify its memory mode before loading.
 * Never resume the overwritten vendor application context; reset to recover.
 * Source: fbb_ws53 acore_memory_config.h, commit 163d9150ab94a02d09a05f623351f9facee3025e.
 */
MEMORY {
    PROGRAM (rx) : ORIGIN = 0x00028000, LENGTH = 32K
    SRAM (rw) : ORIGIN = 0x20050000, LENGTH = 0xFF00
}
__stack_size = DEFINED(__stack_size) ? __stack_size : 0x2000;
__irq_stack_size = DEFINED(__irq_stack_size) ? __irq_stack_size : 0x1000;
__exc_stack_size = DEFINED(__exc_stack_size) ? __exc_stack_size : 0x800;
__nmi_stack_size = DEFINED(__nmi_stack_size) ? __nmi_stack_size : 0x800;

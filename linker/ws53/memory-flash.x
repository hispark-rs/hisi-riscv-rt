/* Experimental WS53 MCU_MODE_1 vendor FlashBoot handoff. Not a whole-chip
 * reset vector, signed container, or ROM/control-core firmware replacement.
 * SDK 163d9150: APP_FLASH_STARTUP_ORIGIN=0x45d300. Physical-SRST observations
 * see DTCM_SHARE=0x20 before allocation; banks0/1 remain ITCM at 0x3c.
 * The bootstrap stack is used only while executing from Flash. The vendor
 * FlashBoot never returns; no old stack/context is resumed.
 */
MEMORY {
    PROGRAM (rx) : ORIGIN = 0x0045D300, LENGTH = 0x212D00
    BOOTSTRAP (rw) : ORIGIN = 0x0002F000, LENGTH = 0x1000
    SRAM (rw) : ORIGIN = 0x20050000, LENGTH = 0xFF00
}
__stack_size = DEFINED(__stack_size) ? __stack_size : 0x2000;
__irq_stack_size = DEFINED(__irq_stack_size) ? __irq_stack_size : 0x1000;
__exc_stack_size = DEFINED(__exc_stack_size) ? __exc_stack_size : 0x800;
__nmi_stack_size = DEFINED(__nmi_stack_size) ? __nmi_stack_size : 0x800;

/*
 * Default memory layout for HiSilicon BS21 / BS2X (RV32IMFC, SLE/NearLink).
 *
 * This is the runtime-provided default for `chip-bs21` + `bundled-memory-x`.
 * BS20 has 128K L2RAM, so BS20 firmware should disable `bundled-memory-x` and
 * provide its own memory.x. Board/vendor images with a different flash partition
 * should do the same.
 *
 *   ROM:      0x00000000 - 0x00080000  (mask ROM window)
 *   ITCM:     0x00080000 - 0x00100000  (512K instruction TCM)
 *   DTCM:     0x000F0000 - 0x00100000  (64K carved from the top of TCM)
 *   L2RAM:    0x00100000 - 0x00128000  (160K main RAM)
 *   FLASH:    0x10000000 - 0x10100000  (1M XIP NOR flash)
 */

MEMORY
{
    /* Mask ROM. Kept for exported symbols; standard Rust apps do not link here. */
    BOOTROM  (rx) : ORIGIN = 0x00000000, LENGTH = 0x8000
    ROM      (rx) : ORIGIN = 0x00008000, LENGTH = 0x78000

    /* Instruction TCM and data TCM. */
    ITCM     (rwx): ORIGIN = 0x00080000, LENGTH = 0x70000
    DTCM     (rw) : ORIGIN = 0x000F0000, LENGTH = 0x10000

    /* XIP NOR flash and program region. */
    FLASH    (rx) : ORIGIN = 0x10000000, LENGTH = 0x100000
    PROGRAM  (rx) : ORIGIN = 0x10000000, LENGTH = 0x100000

    /* Main system RAM (L2RAM, 160K on BS21/BS21E/BS22). */
    SRAM     (rwx): ORIGIN = 0x00100000, LENGTH = 0x28000

    /* Preserved region at the top of L2RAM for boot/runtime state. */
    PRESERVE (rw) : ORIGIN = 0x00128000 - 0x100, LENGTH = 0x100
}

/* Memory regions exported as symbols for runtime relocation. */
PROVIDE(__rom_start = ORIGIN(ROM));
PROVIDE(__rom_length = LENGTH(ROM));
PROVIDE(__itcm_start = ORIGIN(ITCM));
PROVIDE(__itcm_length = LENGTH(ITCM));
PROVIDE(__dtcm_start = ORIGIN(DTCM));
PROVIDE(__dtcm_length = LENGTH(DTCM));
PROVIDE(__sram_start = ORIGIN(SRAM));
PROVIDE(__sram_length = LENGTH(SRAM));
PROVIDE(__flash_start = ORIGIN(FLASH));
PROVIDE(__flash_length = LENGTH(FLASH));
PROVIDE(__program_start = ORIGIN(PROGRAM));
PROVIDE(__program_length = LENGTH(PROGRAM));

/* Stack sizes (can be overridden by user memory/linker fragments). */
__stack_size = DEFINED(__stack_size) ? __stack_size : 0x2000;
__irq_stack_size = DEFINED(__irq_stack_size) ? __irq_stack_size : 0x800;
__exc_stack_size = DEFINED(__exc_stack_size) ? __exc_stack_size : 0x800;
__nmi_stack_size = DEFINED(__nmi_stack_size) ? __nmi_stack_size : 0x400;

/* riscv-rt v0.14 required fallback symbols. layout.ld is authoritative. */
PROVIDE(_stack_start = ORIGIN(SRAM) + LENGTH(SRAM));
PROVIDE(_max_hart_id = 0);
PROVIDE(_hart_stack_size = 0x2000);
PROVIDE(__sidata = 0);
PROVIDE(__sdata = 0);
PROVIDE(__edata = 0);
PROVIDE(__sbss = 0);
PROVIDE(__ebss = 0);

/* riscv-rt v0.14 region aliases. */
REGION_ALIAS("REGION_TEXT", PROGRAM);
REGION_ALIAS("REGION_RODATA", PROGRAM);
REGION_ALIAS("REGION_DATA", SRAM);
REGION_ALIAS("REGION_BSS", SRAM);
REGION_ALIAS("REGION_STACK", SRAM);
REGION_ALIAS("REGION_HEAP", SRAM);

/*
 * Memory layout for HiSilicon WS63 (RV32IMFC)
 *
 * Default configuration (576K SRAM, 16K ITCM, 16K DTCM):
 *
 *   ROM:      0x100000 - 0x14C000  (304K total: 36K bootrom + 268K ROM)
 *   ITCM:     0x14C000 - 0x150000  (16K default)
 *   DTCM:     0x180000 - 0x184000  (16K default)
 *   PROGRAM:  0x230300 - 0x4F0300  (~2.75MB app code in flash)
 *   SRAM:     0xA00000 - 0xA90000  (576K main system RAM)
 *   FLASH:    0x200000 - 0xA00000  (8MB SPI NOR flash)
 *
 * TCM and SRAM sizes are configurable via CONFIG flags (see fbb_ws63 reference).
 */

MEMORY
{
    /* Boot ROM (mask ROM, 36K) */
    BOOTROM  (rx) : ORIGIN = 0x100000, LENGTH = 0x9000

    /* Application ROM (268K: SFC, pinmux, watchdog, timer, systick, TCXO, BT, WiFi) */
    ROM      (rx) : ORIGIN = 0x109000, LENGTH = 0x43000

    /* Instruction TCM (16K default, configurable up to 64K) */
    ITCM     (rwx): ORIGIN = 0x14C000, LENGTH = 0x4000

    /* Data TCM (16K default, configurable up to 64K) */
    DTCM     (rw) : ORIGIN = 0x180000, LENGTH = 0x4000

    /* External SPI NOR flash (8MB, XIP) */
    FLASH    (rx) : ORIGIN = 0x200000, LENGTH = 0x800000

    /* Program region in flash (application code, starts after boot header) */
    PROGRAM  (rx) : ORIGIN = 0x230300, LENGTH = 0x240000

    /* Main system RAM (SRAM/L2RAM, 576K default) */
    SRAM     (rwx): ORIGIN = 0xA00000, LENGTH = 0x90000

    /* Preserved region (256 bytes at end of SRAM for boot state) */
    PRESERVE (rw) : ORIGIN = 0xA90000 - 0x100, LENGTH = 0x100
}

/* Memory regions exported as symbols for runtime relocation */
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

/* Stack sizes (can be overridden by user) */
__stack_size = DEFINED(__stack_size) ? __stack_size : 0x2000;     /* 8KB user stack */
__irq_stack_size = DEFINED(__irq_stack_size) ? __irq_stack_size : 0x800;   /* 2KB IRQ */
__exc_stack_size = DEFINED(__exc_stack_size) ? __exc_stack_size : 0x800;   /* 2KB exception */
__nmi_stack_size = DEFINED(__nmi_stack_size) ? __nmi_stack_size : 0x400;   /* 1KB NMI */

/* ── riscv-rt v0.14 required symbols (MUST be before memory.x closes) ── */
/* Stack: top of SRAM = 0xA00000 + 0x90000 = 0xA90000 */
PROVIDE(_stack_start = ORIGIN(SRAM) + LENGTH(SRAM));
PROVIDE(_max_hart_id = 0);
PROVIDE(_hart_stack_size = 0x2000);

/* IRQ/exception/NMI stack tops are defined authoritatively in layout.ld's
   .stacks section (the trap handlers in asm/ws63/startup.S reference them, and the
   KEEP'd .trap sections keep those references alive through --gc-sections).
   The earlier top-of-SRAM fallbacks here were removed: they overlapped the
   .heap region. See layout.ld .stacks. */

/* Data/bss: these come from layout.ld section definitions.
   The PROVIDE here is a fallback; layout.ld has the authoritative values. */
PROVIDE(__sidata = 0);
PROVIDE(__sdata = 0);
PROVIDE(__edata = 0);
PROVIDE(__sbss = 0);
PROVIDE(__ebss = 0);

/* ── riscv-rt v0.14 region aliases ──────────────────────────────── */
REGION_ALIAS("REGION_TEXT", PROGRAM);
REGION_ALIAS("REGION_RODATA", PROGRAM);
REGION_ALIAS("REGION_DATA", SRAM);
REGION_ALIAS("REGION_BSS", SRAM);
REGION_ALIAS("REGION_STACK", SRAM);
REGION_ALIAS("REGION_HEAP", SRAM);

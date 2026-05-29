/*
 * Interrupt vector definitions for WS63.
 *
 * These PROVIDE entries create weak default handler symbols
 * for every external interrupt source on the WS63 chip.
 * Users override these by defining a function with the same name.
 *
 * The interrupt numbers match the WS63 SYS_CTL1 interrupt controller:
 *   MIE interrupts (bits 26-31):  TIMER(0-2), RTC, I2C0, I2C1
 *   Local interrupts (IRQ 0-59): GPIO, UART, SPI, I2C, DMA, BLE, WiFi, etc.
 */

PROVIDE(DefaultHandler = default_handler);

/* ── riscv-rt v0.14 default exception handlers ────────────────── */
PROVIDE(SupervisorSoft = DefaultHandler);
PROVIDE(MachineSoft = DefaultHandler);
PROVIDE(SupervisorTimer = DefaultHandler);
PROVIDE(MachineTimer = DefaultHandler);
PROVIDE(SupervisorExternal = DefaultHandler);
PROVIDE(MachineExternal = DefaultHandler);
PROVIDE(InstructionMisaligned = DefaultHandler);
PROVIDE(InstructionFault = DefaultHandler);
PROVIDE(IllegalInstruction = DefaultHandler);
PROVIDE(Breakpoint = DefaultHandler);
PROVIDE(LoadMisaligned = DefaultHandler);
PROVIDE(LoadFault = DefaultHandler);
PROVIDE(StoreMisaligned = DefaultHandler);
PROVIDE(StoreFault = DefaultHandler);
PROVIDE(UserEnvCall = DefaultHandler);
PROVIDE(SupervisorEnvCall = DefaultHandler);
PROVIDE(MachineEnvCall = DefaultHandler);
PROVIDE(InstructionPageFault = DefaultHandler);
PROVIDE(LoadPageFault = DefaultHandler);
PROVIDE(StorePageFault = DefaultHandler);

/* ── riscv-rt v0.14 multi-hart / stack symbols ──────────────── */
PROVIDE(_max_hart_id = 0);
PROVIDE(_hart_stack_size = __stack_size);
PROVIDE(_stack_start = __stack_top__);

/* ── riscv-rt v0.14 data/bss linker symbols ──────────────────── */
/* These map layout.ld's __data_begin__/__bss_begin__ naming
   to riscv-rt's expected __sdata/__sbss naming. The actual values
   come from layout.ld via PROVIDE fallback. */
PROVIDE(__sidata = __data_load__);
PROVIDE(__sdata   = __data_begin__);
PROVIDE(__edata   = __data_end__);
PROVIDE(__sbss    = __bss_begin__);
PROVIDE(__ebss    = __bss_end__);

/* MIE interrupt sources (6 entries, bits 26-31 in mie CSR) */
PROVIDE(TIMER_INT0 = DefaultHandler);
PROVIDE(TIMER_INT1 = DefaultHandler);
PROVIDE(TIMER_INT2 = DefaultHandler);
PROVIDE(RTC_IRQ = DefaultHandler);
PROVIDE(I2C0_INT = DefaultHandler);
PROVIDE(I2C1_INT = DefaultHandler);

/* Local interrupt sources (IRQ 0-5: reserved/BT) */
PROVIDE(BT_INT0 = DefaultHandler);
PROVIDE(BT_INT1 = DefaultHandler);
PROVIDE(RESERVE_HANDLER = DefaultHandler);

/* Local interrupt sources (IRQ 6-15) */
PROVIDE(MCU_PCLR_LOCK = DefaultHandler);
PROVIDE(GPIO_INT0 = DefaultHandler);
PROVIDE(GPIO_INT1 = DefaultHandler);
PROVIDE(GPIO_INT2 = DefaultHandler);
PROVIDE(UART0_INT = DefaultHandler);
PROVIDE(UART1_INT = DefaultHandler);
PROVIDE(UART2_INT = DefaultHandler);

/* Local interrupt sources (IRQ 16-25: QSPI, SPI, key scan, PMU, RTC) */
PROVIDE(QSPI0_INT = DefaultHandler);
PROVIDE(QSPI1_INT = DefaultHandler);
PROVIDE(SPI4_S_INT = DefaultHandler);
PROVIDE(KEY_SCAN_INT = DefaultHandler);
PROVIDE(PMU_WAKEUP_INT = DefaultHandler);
PROVIDE(PMU_SLEEP_INT = DefaultHandler);
PROVIDE(RTC_TIMER_ISR0 = DefaultHandler);
PROVIDE(RTC_TIMER_ISR1 = DefaultHandler);
PROVIDE(RTC_TIMER_ISR2 = DefaultHandler);
PROVIDE(RTC_TIMER_ISR3 = DefaultHandler);

/* Local interrupt sources (IRQ 26-35: Timer, SDMA, DMA, SPI, I2C) */
PROVIDE(TIMER_ISR0 = DefaultHandler);
PROVIDE(TIMER_ISR1 = DefaultHandler);
PROVIDE(TIMER_ISR2 = DefaultHandler);
PROVIDE(TIMER_ISR3 = DefaultHandler);
PROVIDE(SDMA_INT = DefaultHandler);
PROVIDE(DMA_INT = DefaultHandler);
PROVIDE(SPI_MS0_INT = DefaultHandler);
PROVIDE(SPI_MS1_INT = DefaultHandler);
PROVIDE(SPI_M_INT = DefaultHandler);

/* Local interrupt sources (IRQ 36-47: I2C, SPI, eFlash, security, PWM) */
PROVIDE(I2C_0_INT = DefaultHandler);
PROVIDE(I2C_1_INT = DefaultHandler);
PROVIDE(I2C_2_INT = DefaultHandler);
PROVIDE(SPI3_MS_INT = DefaultHandler);
PROVIDE(EFLASH_INT = DefaultHandler);
PROVIDE(SEC_INT = DefaultHandler);
PROVIDE(PWM_0_INT = DefaultHandler);
PROVIDE(PWM_1_INT = DefaultHandler);
PROVIDE(PWM_2_INT = DefaultHandler);
PROVIDE(PWM_3_INT = DefaultHandler);
PROVIDE(PWM_4_INT = DefaultHandler);
PROVIDE(PWM_5_INT = DefaultHandler);

/* Local interrupt sources (IRQ 48-59: PMU/CMU, monitors, watchdog, TSENSOR, etc.) */
PROVIDE(PMU_CMU_INT = DefaultHandler);
PROVIDE(MEM_SUB_MONITOR_INT = DefaultHandler);
PROVIDE(B_SUB_MONITOR_INT = DefaultHandler);
PROVIDE(SHARERAM_MONITOR_INT = DefaultHandler);
PROVIDE(EH2H_BRG_INT = DefaultHandler);
PROVIDE(PMU_32K_CALI_INT = DefaultHandler);
PROVIDE(WDT_INT = DefaultHandler);
PROVIDE(TSENSOR_INT = DefaultHandler);
PROVIDE(QDEC_INT = DefaultHandler);
PROVIDE(USB_INT = DefaultHandler);

/* Additional WiFi/BT interrupt sources (from SVD PAC) */
PROVIDE(COEX_WL_INT = DefaultHandler);
PROVIDE(COEX_BT_INT = DefaultHandler);
PROVIDE(COEX_WIFI_RESUME_INT = DefaultHandler);
PROVIDE(SPI_INT = DefaultHandler);
PROVIDE(WLPHY_INT = DefaultHandler);
PROVIDE(WLMAC_INT = DefaultHandler);
PROVIDE(BLE_INT = DefaultHandler);
PROVIDE(SLE_INT = DefaultHandler);
PROVIDE(PMU_CMU_ERR_INT = DefaultHandler);
PROVIDE(DIAG_INT = DefaultHandler);
PROVIDE(I2S_INT = DefaultHandler);
PROVIDE(QSPI_INT = DefaultHandler);
PROVIDE(PWM_ABNOR_INT = DefaultHandler);
PROVIDE(PWM_CFG_INT = DefaultHandler);
PROVIDE(SFC_INT = DefaultHandler);
PROVIDE(TIMER_ABNOR_INT = DefaultHandler);
PROVIDE(I2S_TX_INT = DefaultHandler);
PROVIDE(I2S_RX_INT = DefaultHandler);
PROVIDE(PKE_REE_INT = DefaultHandler);
PROVIDE(SPACC_REE_INT = DefaultHandler);
PROVIDE(RKP_REE_INT = DefaultHandler);
PROVIDE(KLAD_REE_INT = DefaultHandler);
PROVIDE(MAC_MONITOR_INT = DefaultHandler);
PROVIDE(MEM_MONITOR_INT = DefaultHandler);
PROVIDE(TCM_MONITOR_INT = DefaultHandler);
PROVIDE(LSADC_INTR = DefaultHandler);

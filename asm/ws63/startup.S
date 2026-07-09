# ----------------------------------------------------------------------
#  Assembly startup for HiSilicon WS63 (RISC-V RV32IMFC)
#
#  Startup sequence:
#  1. Leave PMP untouched on real silicon (vendor PMP clearing is EDA-only)
#  2. Set mtvec to trap_vector
#  3. Clear mstatus (disable interrupts)
#  4. Clear mie (disable all interrupt sources)
#  5. Enable FPU (set FS=0b11 in mstatus)
#  6. Clear fcsr (FPU exception flags)
#  7. Initialize global pointer (gp)
#  8. Initialize stack pointer (sp = __stack_top__)
#  9. Fill stack area with canary (0xefbeadde)
# 10. Call runtime_init() — Rust code handles BSS zero, data copy
# 11. runtime_init() calls main() — never returns
# ----------------------------------------------------------------------

.section .text.entry, "ax"
.global reset_vector
.option rvc

.ifndef __hisi_startup_uart_trace
.set __hisi_startup_uart_trace, 0
.endif

.macro startup_uart_putc ch
.if __hisi_startup_uart_trace
1:
    li    t5, 0x44010044
    lhu   t6, 0(t5)
    andi  t6, t6, 1
    bnez  t6, 1b
    li    t5, 0x44010004
    li    t6, \ch
    sh    t6, 0(t5)
.endif
.endm

.macro startup_uart_mark a, b, c, d
.if __hisi_startup_uart_trace
    startup_uart_putc \a
    startup_uart_putc \b
    startup_uart_putc \c
    startup_uart_putc \d
    startup_uart_putc 13
    startup_uart_putc 10
.endif
.endm

# ----------------------------------------------------------------------
#  Reset entry point — linked as the very first thing in program memory
# ----------------------------------------------------------------------
reset_vector:
    startup_uart_mark 82, 84, 48, 33
    j HandleReset

HandleReset:
    # ---- PMP is intentionally left untouched on real WS63 silicon -----
    # The vendor startup only clears pmpcfg* in the CHIP_EDA simulation path.
    # On real app boot, writing pmpcfg0 here traps before mtvec is installed.

    # ---- Set trap vector base in DIRECT mode (mtvec[1:0] = 00) ----
    # The WS63 (Nuclei-derived) core does NOT take its custom local/MIE interrupts
    # (mcause/mip bit >= 16, e.g. TIMER_INT0 = 26) through VECTORED mtvec: on
    # silicon, mip[26]=mie[26]=mstatus.MIE=1 yet the interrupt is never serviced
    # (see memory ws63-vectored-irq-not-delivered). In DIRECT mode all traps land on
    # `trap_vector` (entry 0 = `j trap_entry`), and trap_entry branches on mcause's
    # interrupt bit to dispatch interrupts by number to named device.x handlers
    # (`__rt_irq_dispatch`) — the path the async/embassy examples prove works.
    la    t0, trap_vector
    csrw  mtvec, t0

    # ---- Disable interrupts during init ----
    csrwi mstatus, 0
    csrwi mie, 0

    # ---- Enable FPU (FS = 0b11 = Dirty) ----
    li    t0, 0x00006000
    csrs  mstatus, t0
    csrwi fflags, 0              /* Clear FPU exception flags (LLVM-compatible) */

    # ---- Initialize global pointer ----
    .option push
    .option norelax
    la    gp, _gp_
    .option pop

    # ---- Initialize stack pointer ----
    la    sp, __stack_top__

    # ---- Fill stack with canary pattern ----
    la    t0, __stack_start__
    la    t1, __stack_top__
    beq   t0, t1, end_stack_fill
    li    t2, 0xefbeadde
stack_fill_loop:
    sw    t2, 0(t0)
    addi  t0, t0, 4
    blt   t0, t1, stack_fill_loop
end_stack_fill:
    startup_uart_mark 82, 84, 49, 33

    # ---- Jump to Rust runtime init ----
    tail  runtime_init


# ======================================================================
#  Trap vector table
#  WS63 uses a custom vectored interrupt mode:
#  - Entry 0:  trap_entry (all exceptions)
#  - Entry 12: nmi_vector (Non-Maskable Interrupt)
#  - Entries 26-31: default_interrupt0-5_handler (MIE interrupts)
#  - Entries 32-91: default_local_interrupt_handler (60 local IRQs)
# ======================================================================

.section .trap, "ax"
.align 6   # 256-byte aligned (RV32 vectored mode requirement)

.global trap_vector
trap_vector:
.option norvc
    j trap_entry              # 0:  Exception handler
    j default_handler         # 1
    j default_handler         # 2
    j default_handler         # 3
    j default_handler         # 4
    j default_handler         # 5
    j default_handler         # 6
    j default_handler         # 7
    j default_handler         # 8
    j default_handler         # 9
    j default_handler         # 10
    j default_handler         # 11
    j nmi_vector              # 12: NMI handler
    j default_handler         # 13
    j default_handler         # 14
    j default_handler         # 15
    j default_handler         # 16
    j default_handler         # 17
    j default_handler         # 18
    j default_handler         # 19
    j default_handler         # 20
    j default_handler         # 21
    j default_handler         # 22
    j default_handler         # 23
    j default_handler         # 24
    j default_handler         # 25
    j mie_interrupt0_handler  # 26: MIE IRQ 0 (TIMER_INT0)
    j mie_interrupt1_handler  # 27: MIE IRQ 1 (TIMER_INT1)
    j mie_interrupt2_handler  # 28: MIE IRQ 2 (TIMER_INT2)
    j mie_interrupt3_handler  # 29: MIE IRQ 3 (RTC_IRQ)
    j mie_interrupt4_handler  # 30: MIE IRQ 4 (I2C0_INT)
    j mie_interrupt5_handler  # 31: MIE IRQ 5 (I2C1_INT)
# Local interrupt vectors (32-91, 60 entries)
.rept 60
    j local_interrupt_handler
.endr
.option rvc

# ======================================================================
#  Exception vectors jump table (in .rodata, index by mcause)
# ======================================================================
.section .rodata
.align 4
.global excp_vect_table
excp_vect_table:
    .word do_insn_misaligned    # 0
    .word do_insn_fault         # 1
    .word do_insn_illegal       # 2
    .word do_breakpoint         # 3
    .word do_load_misaligned    # 4
    .word do_load_fault         # 5
    .word do_store_misaligned   # 6
    .word do_store_fault        # 7
    .word do_ecall_u            # 8
    .word do_ecall_s            # 9
    .word default_exc_handler   # 10 (reserved)
    .word do_ecall_m            # 11
    .word do_insn_page_fault    # 12
    .word do_load_page_fault    # 13
    .word default_exc_handler   # 14 (reserved)
    .word do_store_page_fault   # 15
    .word default_exc_handler   # 16+
excp_vect_table_end:

# ======================================================================
#  Interrupt dispatch table (.rodata), indexed by IRQ number (mcause low bits).
#  __rt_irq_dispatch (DIRECT-mode path) loads __INTERRUPTS[irq] and tail-calls it.
#  Names + numbers follow the active PAC's ExternalInterrupt enum. Each entry is a
#  `device.x` PROVIDE weak symbol (= DefaultHandler) the application overrides by
#  defining a function of the same name (e.g. `#[no_mangle] extern "C" fn TIMER_INT0()`).
# ======================================================================
.section .rodata
.align 4
.global __INTERRUPTS
__INTERRUPTS:
.ifdef __hisi_chip_bs2x
    .word DefaultHandler        # 0
    .word DefaultHandler        # 1
    .word DefaultHandler        # 2
    .word DefaultHandler        # 3
    .word DefaultHandler        # 4
    .word DefaultHandler        # 5
    .word DefaultHandler        # 6
    .word DefaultHandler        # 7
    .word DefaultHandler        # 8
    .word DefaultHandler        # 9
    .word DefaultHandler        # 10
    .word DefaultHandler        # 11
    .word DefaultHandler        # 12
    .word DefaultHandler        # 13
    .word DefaultHandler        # 14
    .word DefaultHandler        # 15
    .word DefaultHandler        # 16
    .word DefaultHandler        # 17
    .word DefaultHandler        # 18
    .word DefaultHandler        # 19
    .word DefaultHandler        # 20
    .word DefaultHandler        # 21
    .word DefaultHandler        # 22
    .word DefaultHandler        # 23
    .word DefaultHandler        # 24
    .word DefaultHandler        # 25
    .word BT_INT0               # 26
    .word BT_INT1               # 27
    .word GADC_DONE             # 28
    .word GADC_ALARM            # 29
    .word DefaultHandler        # 30 (gap)
    .word DefaultHandler        # 31 (gap)
    .word MCU_PCLR_LOCK         # 32
    .word ULP_GPIO              # 33
    .word GPIO_0                # 34
    .word GPIO_1                # 35
    .word BT_TOGGLE_POS         # 36
    .word BT_TOGGLE_NEG         # 37
    .word KEY_SCAN_LOW_POWER    # 38
    .word UART_0                # 39
    .word MCU_SIMO1P1_VSET      # 40
    .word UART_1                # 41
    .word UART_2                # 42
    .word QSPI0_2CS             # 43
    .word PDM                   # 44
    .word DefaultHandler        # 45 (gap)
    .word KEY_SCAN              # 46
    .word M_WAKEUP              # 47
    .word M_SLEEP               # 48
    .word RTC_0                 # 49
    .word RTC_1                 # 50
    .word RTC_2                 # 51
    .word RTC_3                 # 52
    .word TIMER_0               # 53
    .word TIMER_1               # 54
    .word TIMER_2               # 55
    .word TIMER_3               # 56
    .word M_SDMA                # 57
    .word DefaultHandler        # 58 (gap)
    .word SPI_M_S_0             # 59
    .word SPI_M_S_1             # 60
    .word SPI_M                 # 61
    .word I2C_0                 # 62
    .word I2C_1                 # 63
    .word BT_BB_BT              # 64
    .word BT_BB_BLE             # 65
    .word BT_BB_GLE             # 66
    .word I2S                   # 67
    .word RF_PRT                # 68
    .word NFC                   # 69
    .word SEC                   # 70
    .word PWM_0                 # 71
    .word PWM_1                 # 72
    .word OSC_EN_WKUP           # 73
    .word OSC_EN_SLEEP          # 74
    .word DefaultHandler        # 75 (gap)
    .word DefaultHandler        # 76 (gap)
    .word DefaultHandler        # 77 (gap)
    .word PMU_CMU_ERR           # 78
    .word ULP_INT               # 79
    .word DefaultHandler        # 80 (gap)
    .word DefaultHandler        # 81 (gap)
    .word DefaultHandler        # 82 (gap)
    .word DefaultHandler        # 83 (gap)
    .word DefaultHandler        # 84 (gap)
    .word PMU2_CLK_32K_CALI     # 85
    .word ULP_WKUP_INT          # 86
    .word TSENSOR               # 87
    .word QDEC                  # 88
    .word USB                   # 89
.else
    .word DefaultHandler        # 0
    .word DefaultHandler        # 1
    .word DefaultHandler        # 2
    .word DefaultHandler        # 3
    .word DefaultHandler        # 4
    .word DefaultHandler        # 5
    .word DefaultHandler        # 6
    .word DefaultHandler        # 7
    .word DefaultHandler        # 8
    .word DefaultHandler        # 9
    .word DefaultHandler        # 10
    .word DefaultHandler        # 11
    .word DefaultHandler        # 12
    .word DefaultHandler        # 13
    .word DefaultHandler        # 14
    .word DefaultHandler        # 15
    .word DefaultHandler        # 16
    .word DefaultHandler        # 17
    .word DefaultHandler        # 18
    .word DefaultHandler        # 19
    .word DefaultHandler        # 20
    .word DefaultHandler        # 21
    .word DefaultHandler        # 22
    .word DefaultHandler        # 23
    .word DefaultHandler        # 24
    .word DefaultHandler        # 25
    .word TIMER_INT0            # 26
    .word TIMER_INT1            # 27
    .word TIMER_INT2            # 28
    .word RTC_IRQ              # 29
    .word DefaultHandler        # 30 (gap)
    .word I2C0_INT             # 31
    .word I2C1_INT             # 32
    .word GPIO_INT0            # 33
    .word GPIO_INT1            # 34
    .word GPIO_INT2            # 35
    .word DefaultHandler        # 36 (gap)
    .word DefaultHandler        # 37 (gap)
    .word DefaultHandler        # 38 (gap)
    .word DefaultHandler        # 39 (gap)
    .word COEX_WL_INT          # 40
    .word COEX_BT_INT          # 41
    .word COEX_WIFI_RESUME_INT # 42
    .word SPI_INT             # 43
    .word WLPHY_INT           # 44
    .word WLMAC_INT           # 45
    .word BLE_INT             # 46
    .word SLE_INT             # 47
    .word TSENSOR_INT         # 48
    .word PMU_CMU_ERR_INT      # 49
    .word DIAG_INT            # 50
    .word I2S_INT            # 51
    .word QSPI_INT           # 52
    .word UART0_INT           # 53
    .word UART1_INT           # 54
    .word UART2_INT           # 55
    .word PWM_ABNOR_INT        # 56
    .word PWM_CFG_INT          # 57
    .word SFC_INT            # 58
    .word DMA_INT            # 59
    .word TIMER_ABNOR_INT      # 60
    .word I2S_TX_INT          # 61
    .word I2S_RX_INT          # 62
    .word PKE_REE_INT         # 63
    .word SPACC_REE_INT        # 64
    .word RKP_REE_INT         # 65
    .word KLAD_REE_INT         # 66
    .word DefaultHandler        # 67 (gap)
    .word DefaultHandler        # 68 (gap)
    .word MAC_MONITOR_INT      # 69
    .word MEM_MONITOR_INT      # 70
    .word TCM_MONITOR_INT      # 71
    .word LSADC_INTR          # 72
.endif
__INTERRUPTS_end:
.set __INTERRUPTS_len, (__INTERRUPTS_end - __INTERRUPTS) / 4


# ======================================================================
#  Push / pop register macros
# ======================================================================

.equ ccause, 0xFC2    # WS63 custom CSR for extended exception cause

# Lightweight: 32-word save for interrupt handlers
.macro push_reg
    addi sp, sp, -32*4
    sw ra,  0*4(sp)
    sw sp,  1*4(sp)
    sw gp,  2*4(sp)
    sw tp,  3*4(sp)
    sw t0,  4*4(sp)
    sw t1,  5*4(sp)
    sw t2,  6*4(sp)
    sw s0,  7*4(sp)
    sw s1,  8*4(sp)
    sw a0,  9*4(sp)
    sw a1, 10*4(sp)
    sw a2, 11*4(sp)
    sw a3, 12*4(sp)
    sw a4, 13*4(sp)
    sw a5, 14*4(sp)
    sw a6, 15*4(sp)
    sw a7, 16*4(sp)
    sw s2, 17*4(sp)
    sw s3, 18*4(sp)
    sw s4, 19*4(sp)
    sw s5, 20*4(sp)
    sw s6, 21*4(sp)
    sw s7, 22*4(sp)
    sw s8, 23*4(sp)
    sw s9, 24*4(sp)
    sw s10,25*4(sp)
    sw s11,26*4(sp)
    sw t3, 27*4(sp)
    sw t4, 28*4(sp)
    sw t5, 29*4(sp)
    sw t6, 30*4(sp)
    csrr t0, mepc
    sw   t0, 31*4(sp)
.endm

.macro pop_reg
    lw    t0, 31*4(sp)
    csrw  mepc, t0
    lw ra,   0*4(sp)
    lw t0,   4*4(sp)
    lw t1,   5*4(sp)
    lw t2,   6*4(sp)
    lw s0,   7*4(sp)
    lw s1,   8*4(sp)
    lw a0,   9*4(sp)
    lw a1,  10*4(sp)
    lw a2,  11*4(sp)
    lw a3,  12*4(sp)
    lw a4,  13*4(sp)
    lw a5,  14*4(sp)
    lw a6,  15*4(sp)
    lw a7,  16*4(sp)
    lw s2,  17*4(sp)
    lw s3,  18*4(sp)
    lw s4,  19*4(sp)
    lw s5,  20*4(sp)
    lw s6,  21*4(sp)
    lw s7,  22*4(sp)
    lw s8,  23*4(sp)
    lw s9,  24*4(sp)
    lw s10, 25*4(sp)
    lw s11, 26*4(sp)
    lw t3,  27*4(sp)
    lw t4,  28*4(sp)
    lw t5,  29*4(sp)
    lw t6,  30*4(sp)
    addi sp, sp, 32*4
.endm

# Full save: 36-word save for exception handler (includes CSRs)
.macro save_all
    addi sp, sp, -36*4
    sw s11,  8*4(sp)
    sw s10,  9*4(sp)
    sw s9,  10*4(sp)
    sw s8,  11*4(sp)
    sw s7,  12*4(sp)
    sw s6,  13*4(sp)
    sw s5,  14*4(sp)
    sw s4,  15*4(sp)
    sw s3,  16*4(sp)
    sw s2,  17*4(sp)
    sw s1,  18*4(sp)
    sw s0,  19*4(sp)
    sw t6,  20*4(sp)
    sw t5,  21*4(sp)
    sw t4,  22*4(sp)
    sw t3,  23*4(sp)
    sw a7,  24*4(sp)
    sw a6,  25*4(sp)
    sw a5,  26*4(sp)
    sw a4,  27*4(sp)
    sw a3,  28*4(sp)
    sw a2,  29*4(sp)
    sw a1,  30*4(sp)
    sw a0,  31*4(sp)
    sw t2,  32*4(sp)
    sw t1,  33*4(sp)
    sw t0,  34*4(sp)
    sw ra,  35*4(sp)
    csrr s4, ccause
    sw   s4,  0*4(sp)
    csrr s3, mcause
    sw   s3,  1*4(sp)
    csrr s2, mtval
    sw   s2,  2*4(sp)
    sw   gp,  3*4(sp)
    csrr s1, mstatus
    sw   s1,  4*4(sp)
    csrr s0, mepc
    sw   s0,  5*4(sp)
    sw   tp,  6*4(sp)
    sw   sp,  7*4(sp)
.endm

.macro restore_all
    lw    t0, 5*4(sp)
    csrw  mepc, t0
    lw s11,  8*4(sp)
    lw s10,  9*4(sp)
    lw s9,  10*4(sp)
    lw s8,  11*4(sp)
    lw s7,  12*4(sp)
    lw s6,  13*4(sp)
    lw s5,  14*4(sp)
    lw s4,  15*4(sp)
    lw s3,  16*4(sp)
    lw s2,  17*4(sp)
    lw s1,  18*4(sp)
    lw s0,  19*4(sp)
    lw t6,  20*4(sp)
    lw t5,  21*4(sp)
    lw t4,  22*4(sp)
    lw t3,  23*4(sp)
    lw a7,  24*4(sp)
    lw a6,  25*4(sp)
    lw a5,  26*4(sp)
    lw a4,  27*4(sp)
    lw a3,  28*4(sp)
    lw a2,  29*4(sp)
    lw a1,  30*4(sp)
    lw a0,  31*4(sp)
    lw t2,  32*4(sp)
    lw t1,  33*4(sp)
    lw t0,  34*4(sp)
    lw ra,  35*4(sp)
    addi sp, sp, 36*4
.endm


# ======================================================================
#  Exception handler (trap_entry)
# ======================================================================
.section .trap.exception, "ax"
.align 4
trap_entry:
    save_all

    # Mask interrupts during exception handling
    csrci mstatus, 0x08

    # In DIRECT mode all traps land here. mcause bit 31 distinguishes an interrupt
    # (negative as a signed word) from an exception; route interrupts to the
    # by-number named dispatcher and keep the exception path below unchanged.
    bltz s3, _handle_interrupt

    # Save current sp, switch to exception stack
    csrw mscratch, sp
    la   sp, __exc_stack_top__

    # Check if this is an ecall from M-mode (mcause == 11)
    li   t0, 11
    beq  s3, t0, handle_ecall_m

    # Dispatch via exception vector table
    slli t0, s3, 2
    la   t1, excp_vect_table
    la   t2, excp_vect_table_end
    add  t0, t1, t0
    bgeu t0, t2, 1f
    lw   t0, 0(t0)
    csrr a0, mscratch           # a0 = saved sp (for exc_info_t context)
    jalr t0
    j    2f
1:
    call default_exc_handler
2:
    # Restore sp and return
    csrr sp, mscratch
    li   t0, 0x00001800         # MPP=M-mode, MPIE=1
    csrs mstatus, t0

    restore_all
    mret

# ECALL from M-mode: advance mepc by 4, then jump to handler
handle_ecall_m:
    addi s0, s0, 4
    sw   s0, 0*4(sp)
    csrr a0, mscratch
    call do_ecall_m
    j 2b

# ---- Interrupt path (DIRECT mode): dispatch by mcause IRQ number ----
# Reached from trap_entry when mcause bit 31 is set. Context is already saved by
# save_all (s3 = mcause). Compute the IRQ number, hand it to the weak
# `__rt_irq_dispatch` (which routes to the named device.x handler, or is a no-op by
# default), then restore and `mret` with MIE re-enabled.
_handle_interrupt:
    csrw mscratch, sp
    la   sp, __irq_stack_top__
    slli t0, s3, 1              # shift out mcause bit31 (interrupt flag)
    srli a0, t0, 1             # a0 = IRQ number (exception code)
    call __rt_irq_dispatch
    csrr sp, mscratch
    li   t0, 0x1880            # MPP=M-mode, MPIE=1 -> MIE re-enabled after mret
    csrs mstatus, t0
    restore_all
    mret


# ======================================================================
#  NMI handler
# ======================================================================
.section .trap.nmi, "ax"
.align 4
nmi_vector:
    csrci mstatus, 0x08        # Disable interrupts
    save_all

    csrw mscratch, sp
    la   sp, __nmi_stack_top__
    csrr a0, mscratch           # a0 = saved sp (context)
    call nmi_handler

    csrr sp, mscratch
    li   t0, 0x1880             # MPP=M-mode, MPIE=1, MIE=1
    csrs mstatus, t0

    restore_all
    mret


# ======================================================================
#  MIE interrupt handlers (6 dedicated handlers for MIE bits 26-31)
# ======================================================================
.macro mie_interrupt_handler, n
.section .trap.mie\n, "ax"
.align 4
mie_interrupt\n\()_handler:
    csrci mstatus, 0x08
    push_reg
    csrw mscratch, sp
    la   sp, __irq_stack_top__
    call mie\n\()_interrupt_handler   # -> mie0_interrupt_handler .. mie5_interrupt_handler (weak defaults below)
    csrr sp, mscratch
    li   t0, 0x1880
    csrs mstatus, t0
    pop_reg
    mret
.endm

mie_interrupt_handler 0
mie_interrupt_handler 1
mie_interrupt_handler 2
mie_interrupt_handler 3
mie_interrupt_handler 4
mie_interrupt_handler 5


# ======================================================================
#  Local interrupt handler (entries 32-91, 60 custom local IRQs)
# ======================================================================
.section .trap.local, "ax"
.align 4
local_interrupt_handler:
    csrci mstatus, 0x08
    push_reg
    csrw mscratch, sp
    la   sp, __irq_stack_top__
    call local_isr_dispatch
    csrr sp, mscratch
    li   t0, 0x1880
    csrs mstatus, t0
    pop_reg
    mret


# ======================================================================
#  Default handlers (weak — user can override)
# ======================================================================
.section .text.default_handlers, "ax"

    /* ── riscv-rt v0.14 expected exception handler symbols ───── */
    /* These are extern-weak in riscv-rt's exceptions.rs.        */
/* We provide default infinite-loop handlers.               */
.weak SupervisorSoft
SupervisorSoft: j .

.weak MachineSoft
MachineSoft: j .

.weak SupervisorTimer
SupervisorTimer: j .

.weak MachineTimer
MachineTimer: j .

.weak SupervisorExternal
SupervisorExternal: j .

.weak MachineExternal
MachineExternal: j .

.weak InstructionMisaligned
InstructionMisaligned: j .

.weak InstructionFault
InstructionFault: j .

.weak IllegalInstruction
IllegalInstruction: j .

.weak Breakpoint
Breakpoint: j .

.weak LoadMisaligned
LoadMisaligned: j .

.weak LoadFault
LoadFault: j .

.weak StoreMisaligned
StoreMisaligned: j .

.weak StoreFault
StoreFault: j .

.weak UserEnvCall
UserEnvCall: j .

.weak SupervisorEnvCall
SupervisorEnvCall: j .

.weak MachineEnvCall
MachineEnvCall: j .

.weak InstructionPageFault
InstructionPageFault: j .

.weak LoadPageFault
LoadPageFault: j .

.weak StorePageFault
StorePageFault: j .

/* ── Default handler (used by device.x PROVIDE entries) ──── */
.weak default_handler
default_handler:
    j .

.weak default_exc_handler
default_exc_handler:
    j .

.weak nmi_handler
nmi_handler:
    ret

.weak mie0_interrupt_handler
mie0_interrupt_handler:
    ret

.weak mie1_interrupt_handler
mie1_interrupt_handler:
    ret

.weak mie2_interrupt_handler
mie2_interrupt_handler:
    ret

.weak mie3_interrupt_handler
mie3_interrupt_handler:
    ret

.weak mie4_interrupt_handler
mie4_interrupt_handler:
    ret

.weak mie5_interrupt_handler
mie5_interrupt_handler:
    ret

.weak local_isr_dispatch
local_isr_dispatch:
    ret

# Default interrupt dispatcher (DIRECT-mode path). `a0` = IRQ number. Indexes the
# `__INTERRUPTS` table and tail-calls the named device.x handler for that IRQ (the
# handler's `ret` returns into `_handle_interrupt`). Out-of-range IRQs return
# without action. Weak so an application may replace the whole dispatcher if it
# prefers a single hook over per-IRQ named symbols.
.weak __rt_irq_dispatch
__rt_irq_dispatch:
.ifdef __hisi_chip_bs2x
    li   t0, 90                 # BS2X __INTERRUPTS length (IRQ 0..89)
.else
    li   t0, 73                 # WS63 __INTERRUPTS length (IRQ 0..72)
.endif
    bgeu a0, t0, 1f
    la   t0, __INTERRUPTS
    slli t1, a0, 2
    add  t0, t0, t1
    lw   t0, 0(t0)
    jr   t0                     # tail-call __INTERRUPTS[irq] (named handler)
1:
    ret

.weak do_insn_misaligned
do_insn_misaligned:
    j default_exc_handler

.weak do_insn_fault
do_insn_fault:
    j default_exc_handler

.weak do_insn_illegal
do_insn_illegal:
    j default_exc_handler

.weak do_breakpoint
do_breakpoint:
    j default_exc_handler

.weak do_load_misaligned
do_load_misaligned:
    j default_exc_handler

.weak do_load_fault
do_load_fault:
    j default_exc_handler

.weak do_store_misaligned
do_store_misaligned:
    j default_exc_handler

.weak do_store_fault
do_store_fault:
    j default_exc_handler

.weak do_ecall_u
do_ecall_u:
    j default_exc_handler

.weak do_ecall_s
do_ecall_s:
    j default_exc_handler

.weak do_ecall_m
do_ecall_m:
    j default_exc_handler

.weak do_insn_page_fault
do_insn_page_fault:
    j default_exc_handler

.weak do_load_page_fault
do_load_page_fault:
    j default_exc_handler

.weak do_store_page_fault
do_store_page_fault:
    j default_exc_handler


# ======================================================================
#  Global interrupt lock/unlock/restore (for critical sections)
# ======================================================================
.section .text
.global global_interrupt_lock
global_interrupt_lock:
    csrr a0, mstatus
    li   t0, 0x08
    csrrc zero, mstatus, t0
    ret

.global global_interrupt_unlock
global_interrupt_unlock:
    csrr a0, mstatus
    li   t0, 0x08
    csrrs zero, mstatus, t0
    ret

.global global_interrupt_restore
global_interrupt_restore:
    csrw mstatus, a0
    ret

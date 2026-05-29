# ----------------------------------------------------------------------
#  Assembly startup for HiSilicon WS63 (RISC-V RV32IMFC)
#
#  Startup sequence:
#  1. Disable PMP (clear pmpcfg0-3) — EDA workaround
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

# ----------------------------------------------------------------------
#  Reset entry point — linked as the very first thing in program memory
# ----------------------------------------------------------------------
reset_vector:
    j HandleReset

HandleReset:
    # ---- PMP disable (for EDA/simulation environments) -----
    li    t0, 0
    csrw  pmpcfg0, t0
    li    t0, 0
    csrw  pmpcfg1, t0
    li    t0, 0
    csrw  pmpcfg2, t0
    li    t0, 0
    csrw  pmpcfg3, t0

    # ---- Set trap vector base ----
    la    t0, trap_vector
    csrw  mtvec, t0

    # ---- Disable interrupts during init ----
    csrwi mstatus, 0
    csrwi mie, 0

    # ---- Enable FPU (FS = 0b11 = Dirty) ----
    li    t0, 0x00006000
    csrs  mstatus, t0
    fssr  x0

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
    csrr s2, mbadaddr
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
    call mie\()_interrupt_handler
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

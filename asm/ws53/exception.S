# WS53 synchronous exceptions. This is not an NMI source/acknowledgement model.
# Preserve mscratch: an exception can interrupt the IRQ handler that owns it.
# Frame layout matches src/chips/ws53/exception.rs::ExceptionContext (288 B).
.section .trap.ws53_exception, "ax"
.balign 4
.global __ws53_exception_entry
.type __ws53_exception_entry,@function
__ws53_exception_entry:
    addi sp, sp, -288
    sw t0, 20(sp)
    sw zero, 0(sp)
    .irp n,1,3,4,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
        sw x\n, (4*\n)(sp)
    .endr
    addi t0, sp, 288
    sw t0, 8(sp)
    csrr t0, mstatus
    sw t0, 128(sp)
    csrci mstatus, 8
    csrr t0, mepc
    sw t0, 132(sp)
    csrr t0, mcause
    sw t0, 136(sp)
    csrr t0, mtval
    sw t0, 140(sp)
    csrr t0, mscratch
    sw t0, 144(sp)
    # FS may be Off/Clean. Enable it only after retaining the original value.
    li t0, 0x6000
    csrs mstatus, t0
    .option push
    .option arch, +f
    frcsr t0
    sw t0, 148(sp)
    .irp n,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
        fsw f\n, (152+4*\n)(sp)
    .endr
    .option pop
    sw zero, 280(sp)
    sw zero, 284(sp)
    mv s0, sp
    # A nested synchronous exception continues below the active handler stack;
    # never reset to its top and overwrite the outer return address/locals.
    lw t0, 8(s0)
    la t1, __exc_stack_start__
    bltu t0, t1, .Lws53_exception_switch
    la t1, __exc_stack_top__
    bgeu t1, t0, .Lws53_exception_call
.Lws53_exception_switch:
    la sp, __exc_stack_top__
.Lws53_exception_call:
    andi sp, sp, -16
    .option push
    .option norelax
    la gp, _gp_
    .option pop
    mv a0, s0
    call WS53_EXCEPTION
    mv sp, s0
    .option push
    .option arch, +f
    li t0, 0x6000
    csrs mstatus, t0
    lw t0, 148(sp)
    fscsr t0
    .irp n,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
        flw f\n, (152+4*\n)(sp)
    .endr
    .option pop
    lw t0, 132(sp)
    csrw mepc, t0
    lw t0, 136(sp)
    csrw mcause, t0
    lw t0, 140(sp)
    csrw mtval, t0
    lw t0, 144(sp)
    csrw mscratch, t0
    # MRET consumes MPIE. Never enable IRQs with a partially restored frame.
    lw t0, 128(sp)
    andi t0, t0, -9
    csrw mstatus, t0
    .irp n,1,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
        lw x\n, (4*\n)(sp)
    .endr
    lw sp, 8(sp)
    mret
.size __ws53_exception_entry, .-__ws53_exception_entry

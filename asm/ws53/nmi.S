# WS53 software NMI entry. SDK object evidence: interrupt cause12, dedicated
# stack, hook, and MRET. CPU delivery/redelivery semantics remain unverified.
# Frame layout is checked against src/chips/ws53.rs::NmiContext.
# Do not use mscratch as a frame pointer: it may belong to an interrupted IRQ.
.section .trap.ws53_nmi, "ax"
.balign 4
.global __ws53_nmi_entry
__ws53_nmi_entry:
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
    # FS might be Off/Clean at entry; save it before enabling FPU accesses.
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
    # Reentry from a hook continues below that hook's stack, instead of
    # resetting SP to the top and overwriting its return address/local data.
    lw t0, 8(s0)
    la t1, __nmi_stack_start__
    bltu t0, t1, .Lws53_nmi_switch
    la t1, __nmi_stack_top__
    bgeu t1, t0, .Lws53_nmi_call
.Lws53_nmi_switch:
    la sp, __nmi_stack_top__
.Lws53_nmi_call:
    andi sp, sp, -16
    .option push
    .option norelax
    la gp, _gp_
    .option pop
    mv a0, s0
    call WS53_NMI
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
    # Restore FS after the floating loads, which otherwise mark it Dirty.
    # Keep MIE clear until MRET consumes MPIE; no partially restored IRQ frame.
    lw t0, 128(sp)
    andi t0, t0, -9
    csrw mstatus, t0
    .irp n,1,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
        lw x\n, (4*\n)(sp)
    .endr
    lw sp, 8(sp)
    mret

.section .text.ws53_nmi_default, "ax"
.global __ws53_default_nmi
__ws53_default_nmi:
    # No generic source acknowledgement exists. Fail closed until the owner
    # provides a hook; never call the SDK's conflicting 0x20c18 helper.
    j __ws53_default_nmi

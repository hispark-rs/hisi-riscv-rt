# Unified 272-byte task context shared by both WS63 startup adapters.
# Offsets match hisi-rtos::TaskContext and the WS63 LiteOS behavior oracle.
.macro hisi_push_task_context
    addi sp, sp, -68*4
    sw t0, 120(sp)
    csrr t0, mstatus; sw t0, 0(sp)
    csrr t0, mepc; sw t0, 4(sp)
    sw tp, 8(sp)
    addi t0, sp, 68*4; sw t0, 12(sp)
    sw s11, 16(sp); sw s10, 20(sp); sw s9, 24(sp); sw s8, 28(sp)
    sw s7, 32(sp); sw s6, 36(sp); sw s5, 40(sp); sw s4, 44(sp)
    sw s3, 48(sp); sw s2, 52(sp); sw s1, 56(sp); sw s0, 60(sp)
    sw t6, 64(sp); sw t5, 68(sp); sw t4, 72(sp); sw t3, 76(sp)
    sw a7, 80(sp); sw a6, 84(sp); sw a5, 88(sp); sw a4, 92(sp)
    sw a3, 96(sp); sw a2, 100(sp); sw a1, 104(sp); sw a0, 108(sp)
    sw t2, 112(sp); sw t1, 116(sp); sw ra, 124(sp)
    .option push
    .option arch, +f
    fsw fs11, 128(sp); fsw fs10, 132(sp); fsw fs9, 136(sp); fsw fs8, 140(sp)
    fsw fs7, 144(sp); fsw fs6, 148(sp); fsw fs5, 152(sp); fsw fs4, 156(sp)
    fsw fs3, 160(sp); fsw fs2, 164(sp); fsw fs1, 168(sp); fsw fs0, 172(sp)
    fsw ft11, 176(sp); fsw ft10, 180(sp); fsw ft9, 184(sp); fsw ft8, 188(sp)
    fsw fa7, 192(sp); fsw fa6, 196(sp); fsw fa5, 200(sp); fsw fa4, 204(sp)
    fsw fa3, 208(sp); fsw fa2, 212(sp); fsw fa1, 216(sp); fsw fa0, 220(sp)
    fsw ft7, 224(sp); fsw ft6, 228(sp); fsw ft5, 232(sp); fsw ft4, 236(sp)
    fsw ft3, 240(sp); fsw ft2, 244(sp); fsw ft1, 248(sp); fsw ft0, 252(sp)
    frcsr t0; sw t0, 256(sp)
    .option pop
.endm

.macro hisi_pop_task_context
    lw t0, 0(sp); csrw mstatus, t0
    lw t0, 4(sp); csrw mepc, t0
    lw t0, 256(sp)
    .option push
    .option arch, +f
    fscsr t0
    flw fs11, 128(sp); flw fs10, 132(sp); flw fs9, 136(sp); flw fs8, 140(sp)
    flw fs7, 144(sp); flw fs6, 148(sp); flw fs5, 152(sp); flw fs4, 156(sp)
    flw fs3, 160(sp); flw fs2, 164(sp); flw fs1, 168(sp); flw fs0, 172(sp)
    flw ft11, 176(sp); flw ft10, 180(sp); flw ft9, 184(sp); flw ft8, 188(sp)
    flw fa7, 192(sp); flw fa6, 196(sp); flw fa5, 200(sp); flw fa4, 204(sp)
    flw fa3, 208(sp); flw fa2, 212(sp); flw fa1, 216(sp); flw fa0, 220(sp)
    flw ft7, 224(sp); flw ft6, 228(sp); flw ft5, 232(sp); flw ft4, 236(sp)
    flw ft3, 240(sp); flw ft2, 244(sp); flw ft1, 248(sp); flw ft0, 252(sp)
    .option pop
    lw tp, 8(sp)
    lw s11, 16(sp); lw s10, 20(sp); lw s9, 24(sp); lw s8, 28(sp)
    lw s7, 32(sp); lw s6, 36(sp); lw s5, 40(sp); lw s4, 44(sp)
    lw s3, 48(sp); lw s2, 52(sp); lw s1, 56(sp); lw s0, 60(sp)
    lw t6, 64(sp); lw t5, 68(sp); lw t4, 72(sp); lw t3, 76(sp)
    lw a7, 80(sp); lw a6, 84(sp); lw a5, 88(sp); lw a4, 92(sp)
    lw a3, 96(sp); lw a2, 100(sp); lw a1, 104(sp); lw a0, 108(sp)
    lw t2, 112(sp); lw t1, 116(sp); lw t0, 120(sp); lw ra, 124(sp)
    addi sp, sp, 68*4
.endm

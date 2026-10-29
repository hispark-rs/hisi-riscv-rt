//! Experimental synchronous exceptions on the application hart.
//!
//! Override `unsafe extern "C" fn WS53_EXCEPTION(ctx: &mut ExceptionContext)`.
//! Ordinary IRQs stay masked. Do not enable them, acquire locks held by the
//! interrupted code, or let the frame reference escape. The interrupted stack
//! must remain valid/writable with room for a 288-byte frame; bad-stack and
//! prologue faults are not recovered here. Nested handlers need bounded stack
//! budgets. Physical fault delivery and recovery still need named HIL evidence.

/// Saved application state. A synchronous exception can also interrupt an IRQ;
/// the runtime retains that IRQ's `mscratch` rather than borrowing it for dispatch.
#[repr(C)]
pub struct ExceptionContext {
    integer: [u32; 32],
    mstatus: u32,
    mepc: u32,
    mcause: u32,
    mtval: u32,
    mscratch: u32,
    fcsr: u32,
    floating: [u32; 32],
    reserved: [u32; 2],
}

impl ExceptionContext {
    pub fn integer_registers(&self) -> &[u32; 32] {
        &self.integer
    }
    pub fn floating_registers(&self) -> &[u32; 32] {
        &self.floating
    }
    /// Post-trap status before the runtime enables FPU access. MRET restores
    /// the pre-trap interrupt state through MPIE; this is not pre-trap mstatus.
    pub fn status(&self) -> u32 {
        self.mstatus
    }
    pub fn program_counter(&self) -> u32 {
        self.mepc
    }
    pub fn cause(&self) -> u32 {
        self.mcause
    }
    pub fn trap_value(&self) -> u32 {
        self.mtval
    }
    pub fn previous_scratch(&self) -> u32 {
        self.mscratch
    }
    pub fn floating_status(&self) -> u32 {
        self.fcsr
    }

    /// Select the exact instruction address restored by MRET.
    ///
    /// # Safety
    /// The caller must resolve the fault and establish a mapped, executable,
    /// correctly aligned resume point with a valid Rust/ABI continuation and
    /// unchanged register/stack assumptions. Do not blindly skip an unknown
    /// variable-length instruction or return into an invalid borrowed context.
    pub unsafe fn set_program_counter(&mut self, address: u32) {
        self.mepc = address;
    }
}

const _: () = {
    assert!(core::mem::size_of::<ExceptionContext>() == 288);
    assert!(core::mem::align_of::<ExceptionContext>() == 4);
    assert!(core::mem::offset_of!(ExceptionContext, mstatus) == 128);
    assert!(core::mem::offset_of!(ExceptionContext, mepc) == 132);
    assert!(core::mem::offset_of!(ExceptionContext, mcause) == 136);
    assert!(core::mem::offset_of!(ExceptionContext, mtval) == 140);
    assert!(core::mem::offset_of!(ExceptionContext, mscratch) == 144);
    assert!(core::mem::offset_of!(ExceptionContext, fcsr) == 148);
    assert!(core::mem::offset_of!(ExceptionContext, floating) == 152);
};

unsafe extern "C" {
    fn default_exc_handler();
    fn do_insn_misaligned();
    fn do_insn_fault();
    fn do_insn_illegal();
    fn do_breakpoint();
    fn do_load_misaligned();
    fn do_load_fault();
    fn do_store_misaligned();
    fn do_store_fault();
    fn do_ecall_u();
    fn do_ecall_s();
    fn do_ecall_m();
    fn do_insn_page_fault();
    fn do_load_page_fault();
    fn do_store_page_fault();
}

/// Default dispatch preserves the existing zero-argument `do_*` symbols and
/// automatic four-byte M-mode ECALL advance. Other faults retry if an override
/// returns without resolving them. The default alias is a non-returning halt.
///
/// # Safety
/// Dispatch only the current runtime-owned synchronous frame, with ordinary
/// IRQs masked and the documented handler/stack contract in force. Dispatch it
/// once; repeating M-mode ECALL dispatch would advance its resume PC again.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn __ws53_default_exception_dispatch(ctx: &mut ExceptionContext) {
    let handler: unsafe extern "C" fn() = match ctx.cause() {
        0 => do_insn_misaligned,
        1 => do_insn_fault,
        2 => do_insn_illegal,
        3 => do_breakpoint,
        4 => do_load_misaligned,
        5 => do_load_fault,
        6 => do_store_misaligned,
        7 => do_store_fault,
        8 => do_ecall_u,
        9 => do_ecall_s,
        11 => {
            // ECALL is architecturally 32-bit. Preserve the legacy adapter's
            // advance convention without decoding memory or invoking ROM code.
            ctx.mepc = ctx.mepc.wrapping_add(4);
            do_ecall_m
        }
        12 => do_insn_page_fault,
        13 => do_load_page_fault,
        15 => do_store_page_fault,
        _ => default_exc_handler,
    };
    unsafe { handler() };
}

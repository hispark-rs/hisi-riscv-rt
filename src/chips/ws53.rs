//! Application-core RAM takeover, or opt-in vendor FlashBoot handoff.
//! Requires an established MCU_MODE_1 boot environment and an explicit debugger
//! takeover in the default RAM profile. `ws53-flash-start` instead establishes
//! mode1 RAM from the observed vendor boot state with the control core held reset.
//! Clocks/pads are inherited until a HAL driver owns and configures them.
//! The debugger MUST clear `mstatus.MIE` while halted before loading/resuming:
//! setting PC is not reset, and an inherited IRQ can preempt the first instruction.
pub mod cache;
pub mod exception;

use ws53_pac::interrupt::ExternalInterrupt as Irq;

/// Immutable entry snapshot for the experimental WS53 `WS53_NMI` hook.
///
/// Override the default non-returning assembly hook with
/// `#[unsafe(no_mangle)] unsafe extern "C" fn WS53_NMI(ctx: &NmiContext)`.
/// The hook must obey the C ABI, stay within the NMI stack budget, and return
/// only after the owner has resolved the source through a verified protocol.
/// It must not enable ordinary IRQs, change `mscratch`, or use shared Rust
/// state protected only by ordinary interrupt masking: NMI can interrupt that
/// state while borrowed. Do not acquire a lock held by interrupted code.
/// A reference to this frame must not escape the hook.
///
/// Hardware NMI delivery, early-prologue redelivery and source clear semantics
/// are not verified. Software reentry tests do not establish those properties.
/// No SDK NMI trigger/clear helper is called by this runtime.
#[repr(C)]
pub struct NmiContext {
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

impl NmiContext {
    /// Integer registers indexed by their architectural x-register number.
    pub fn integer_registers(&self) -> &[u32; 32] {
        &self.integer
    }
    /// Raw bits of all 32 single-precision floating-point registers.
    pub fn floating_registers(&self) -> &[u32; 32] {
        &self.floating
    }
    /// Machine status captured before this entry enables FPU access.
    pub fn status(&self) -> u32 {
        self.mstatus
    }
    /// Interrupted program counter provided by the CPU (or software test).
    pub fn program_counter(&self) -> u32 {
        self.mepc
    }
    /// Machine cause captured at entry, expected to be `0x8000_000c`.
    pub fn cause(&self) -> u32 {
        self.mcause
    }
    /// Machine trap value captured at entry.
    pub fn trap_value(&self) -> u32 {
        self.mtval
    }
    /// Existing scratch CSR, which may point at an interrupted IRQ frame.
    pub fn previous_scratch(&self) -> u32 {
        self.mscratch
    }
    /// Floating-point control/status captured at entry.
    pub fn floating_status(&self) -> u32 {
        self.fcsr
    }
}

const _: () = {
    assert!(core::mem::size_of::<NmiContext>() == 288);
    assert!(core::mem::align_of::<NmiContext>() == 4);
    assert!(core::mem::offset_of!(NmiContext, mstatus) == 128);
    assert!(core::mem::offset_of!(NmiContext, mepc) == 132);
    assert!(core::mem::offset_of!(NmiContext, mcause) == 136);
    assert!(core::mem::offset_of!(NmiContext, mtval) == 140);
    assert!(core::mem::offset_of!(NmiContext, mscratch) == 144);
    assert!(core::mem::offset_of!(NmiContext, fcsr) == 148);
    assert!(core::mem::offset_of!(NmiContext, floating) == 152);
};

unsafe extern "C" {
    fn main() -> !;
    #[cfg(feature = "ws53-flash-start")]
    fn trap_vector();
    fn DefaultHandler();
    fn SGPIO_INT();
    fn GPIO_0();
    fn GPIO_1();
    fn UART_0();
    fn UART_1();
    fn UART_2();
    fn QSPI0_2CS();
    fn SDIO();
    fn RTC_0();
    fn RTC_1();
    fn TIMER_0();
    fn TIMER_1();
    fn M_DMA();
    fn I2C_0();
    fn I2C_1();
    fn SPI_3();
    fn I2S();
    fn PWM_ABNOR();
    fn PWM_CFG();
    fn LSADC();
    static mut __bss_begin__: u8;
    static mut __bss_end__: u8;
    #[cfg(feature = "ws53-flash-start")]
    static __data_load__: u8;
    #[cfg(feature = "ws53-flash-start")]
    static mut __data_begin__: u8;
    #[cfg(feature = "ws53-flash-start")]
    static mut __data_end__: u8;
    #[cfg(feature = "ws53-ram-functions")]
    static __ws53_ramtext_load: u8;
    #[cfg(feature = "ws53-ram-functions")]
    static mut __ws53_ramtext_begin: u8;
    #[cfg(feature = "ws53-ram-functions")]
    static mut __ws53_ramtext_end: u8;
}

/// Fail before touching application data/stack. The inherited vendor watchdog
/// remains active, so a rejected handoff eventually restarts via vendor boot.
/// No panic handler, console, globals, allocator or uninitialized Rust state.
#[cfg(feature = "ws53-flash-start")]
#[inline(never)]
#[unsafe(no_mangle)]
unsafe extern "C" fn __hisi_ws53_flash_handoff_rejected() -> ! {
    loop {
        core::hint::spin_loop();
    }
}

/// Called by assembly on the private ITCM bootstrap stack, with all local IRQs
/// masked. Source: SDK dyn_mem.c acore_idtcm_dyn_cfg/acore_dtcm_dyn_cfg.
/// This qualified FlashBoot profile has NOT started the vendor control CPU.
/// Keep it held: starting/copying its firmware requires a separate IPC handoff.
#[cfg(feature = "ws53-flash-start")]
#[unsafe(no_mangle)]
unsafe extern "C" fn __hisi_ws53_prepare_flash_ram() {
    let r = unsafe { &*ws53_pac::SystemMemory::PTR };
    let shared = r.bram_share().read();
    // Physical-SRST entry observation, not chip reset defaults. Fail closed on
    // a debugger RAM takeover or any other installed firmware/memory profile.
    if r.ccore_reset_status().read().released_domains().bits() != 0
        || r.dtcm_share().read().dtcm_select().bits() != 0x20
        || r.platform_enable().read().mcu_mode().bits() != 0
        || shared.owner().bits() != 0
        || shared.clock_enable().bits() != 15
        || shared.ccore_offset().bits() != 3
    {
        unsafe { __hisi_ws53_flash_handoff_rejected() }
    }
    // Banks0/1 (including our ITCM stack) keep their interface. No shared
    // DTCM access occurs until the complete gate/owner/gate sequence finishes.
    r.dtcm_share().modify(|_, w| unsafe { w.dtcm_select().bits(0x3c) });
    r.platform_enable().modify(|_, w| unsafe { w.mcu_mode().bits(0) });
    r.bram_share().modify(|_, w| unsafe { w.clock_enable().bits(0) });
    r.bram_share().modify(|_, w| unsafe { w.owner().bits(8) });
    r.bram_share().modify(|_, w| unsafe { w.clock_enable().bits(15) });
    unsafe { core::arch::asm!("fence iorw, iorw", options(nostack)) };
    let shared = r.bram_share().read();
    if r.dtcm_share().read().dtcm_select().bits() != 0x3c
        || shared.owner().bits() != 8
        || shared.clock_enable().bits() != 15
        || shared.ccore_offset().bits() != 3
        || r.ccore_reset_status().read().released_domains().bits() != 0
    {
        unsafe { __hisi_ws53_flash_handoff_rejected() }
    }
}

type Handler = unsafe extern "C" fn();
const fn handlers() -> [Handler; 90] {
    let mut table = [DefaultHandler as Handler; 90];
    table[Irq::SGPIO_INT as usize] = SGPIO_INT;
    table[Irq::GPIO_0 as usize] = GPIO_0;
    table[Irq::GPIO_1 as usize] = GPIO_1;
    table[Irq::UART_0 as usize] = UART_0;
    table[Irq::UART_1 as usize] = UART_1;
    table[Irq::UART_2 as usize] = UART_2;
    table[Irq::QSPI0_2CS as usize] = QSPI0_2CS;
    table[Irq::SDIO as usize] = SDIO;
    table[Irq::RTC_0 as usize] = RTC_0;
    table[Irq::RTC_1 as usize] = RTC_1;
    table[Irq::TIMER_0 as usize] = TIMER_0;
    table[Irq::TIMER_1 as usize] = TIMER_1;
    table[Irq::M_DMA as usize] = M_DMA;
    table[Irq::I2C_0 as usize] = I2C_0;
    table[Irq::I2C_1 as usize] = I2C_1;
    table[Irq::SPI_3 as usize] = SPI_3;
    table[Irq::I2S as usize] = I2S;
    table[Irq::PWM_ABNOR as usize] = PWM_ABNOR;
    table[Irq::PWM_CFG as usize] = PWM_CFG;
    table[Irq::LSADC as usize] = LSADC;
    table
}

#[used]
#[unsafe(no_mangle)]
static __INTERRUPTS: [Handler; 90] = handlers();

#[unsafe(no_mangle)]
unsafe extern "C" fn runtime_init() -> ! {
    #[cfg(feature = "ws53-flash-start")]
    {
        // The linker gives initialized data a Flash LMA and a private RAM VMA.
        // Volatile byte copies cannot turn into a call using uninitialized
        // runtime state. This is RAM initialization, not volatile MMIO.
        let mut source = core::ptr::addr_of!(__data_load__);
        let mut dest = core::ptr::addr_of_mut!(__data_begin__);
        let end = core::ptr::addr_of_mut!(__data_end__);
        while dest < end {
            unsafe {
                dest.write_volatile(source.read_volatile());
                dest = dest.add(1);
                source = source.add(1);
            }
        }
    }
    // Clear only this ELF's BSS. RAM takeover instead has its initialized data
    // loaded at the VMA by the debugger, so it needs no copy.
    let mut cursor = core::ptr::addr_of_mut!(__bss_begin__);
    let end = core::ptr::addr_of_mut!(__bss_end__);
    while cursor < end {
        unsafe {
            cursor.write_volatile(0);
            cursor = cursor.add(1);
        }
    }
    #[cfg(feature = "ws53-ram-functions")]
    {
        // Dedicated application ITCM, never the bootstrap stack. The early
        // stackless trap remains active until copy and fence.i both finish.
        // Volatile byte copies avoid a compiler-generated memcpy dependency.
        let mut source = core::ptr::addr_of!(__ws53_ramtext_load);
        let mut dest = core::ptr::addr_of_mut!(__ws53_ramtext_begin);
        let end = core::ptr::addr_of_mut!(__ws53_ramtext_end);
        while dest < end {
            unsafe {
                dest.write_volatile(source.read_volatile());
                dest = dest.add(1);
                source = source.add(1);
            }
        }
    }
    // Disable inherited application-core local IRQ enables. Do not touch the
    // control core, PMU, memory partitioning or system-wide reset controls.
    unsafe {
        core::arch::asm!("csrw 0xbe0, zero", "csrw 0xbe1, zero", "csrw 0xbe2, zero", "fence.i");
        // Only now are the application, exception and NMI stacks and all Rust
        // static data ready. Earlier Flash handoff faults use the stackless
        // assembly stop path, including failures during data/BSS initialization.
        #[cfg(feature = "ws53-flash-start")]
        core::arch::asm!("csrw mtvec, {vector}", vector = in(reg) trap_vector as *const (), options(nostack));
        main()
    }
}

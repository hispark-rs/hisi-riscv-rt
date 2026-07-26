//! # hisi-riscv-rt
//!
//! Runtime entry support for HiSilicon RISC-V firmware.
//!
//! The public crate interface is intentionally small: it re-exports the
//! `riscv-rt` entry attributes, the selected chip PAC's interrupt enum, and the
//! single-hart critical-section implementation configured through the `riscv`
//! crate. Chip-specific reset code, linker fragments, and image headers live
//! behind startup adapters.
//!
//! Current adapters:
//! - `chip-ws63`: WS63 startup, linker layout, interrupt symbols, and optional
//!   link-time boot header.
//! - `chip-bs21` + `unstable`: BS2X compatibility path.
//!
//! Downstream binaries should link with `-Thisi-riscv-link.x`.
//!
//! # Architecture overview
//!
//! ```text
//! Power-on / reset
//!   │
//!   ▼
//! reset_vector (asm/ws63/startup.S)
//!   ├── Clear PMP, set mtvec, disable interrupts
//!   ├── Enable FPU, initialize gp / sp
//!   ├── Fill stack canary
//!   └── tail runtime_init
//!         │
//!         ▼
//!       runtime_init() (Rust, chips/ws63/startup.rs)
//!         ├── Shared-RAM init (dyn_mem_cfg)
//!         ├── Cache init & invalidate
//!         ├── Multi-region relocation (ROM data, TCM text/data, SRAM text/data)
//!         ├── BSS zeroing
//!         ├── ROM patch enable
//!         ├── MIE bits set (TIMER0-2, RTC, I2C0, I2C1)
//!         └── call main()
//!               │
//!               ▼
//!             your #[entry] fn main() -> !
//! ```
//!
//! ```text
//! Interrupt arrives
//!   │
//!   ▼
//! mtvec → trap_vector (vectored mode)
//!   ├── mie_interruptX_handler / local_interrupt_handler
//!   │     ├── csrci mstatus, 0x08          (disable interrupts)
//!   │     ├── hisi_push_task_context       (save 272B unified frame)
//!   │     ├── csrw mscratch, sp            (stash frame pointer)
//!   │     ├── la sp, __irq_stack_top__     (switch to IRQ stack)
//!   │     ├── call user_handler            (weak symbol override)
//!   │     ├── csrr a0, mscratch            (a0 = frame)
//!   │     ├── call __hisi_irq_epilogue     (RTOS scheduling hook)
//!   │     ├── j __hisi_resume_trap         (restore frame + mret)
//!   │
//!   ├── trap_entry (exceptions)
//!   │     ├── save_all                     (save 36-word frame incl. CSRs)
//!   │     ├── csrw mscratch, sp
//!   │     ├── la sp, __exc_stack_top__
//!   │     ├── dispatch via excp_vect_table
//!   │     ├── csrr sp, mscratch
//!   │     ├── restore_all + mret
//!   │
//!   └── nmi_vector
//!         ├── csrci mstatus, 0x08
//!         ├── save_all
//!         ├── csrw mscratch, sp
//!         ├── la sp, __nmi_stack_top__
//!         ├── call nmi_handler
//!         ├── csrr sp, mscratch
//!         ├── restore_all + mret
//! ```
//!
//! # Quick start
//!
//! ```rust,ignore
//! #![no_std]
//! #![no_main]
//!
//! use hisi_riscv_rt::entry;
//!
//! #[entry]
//! fn main() -> ! {
//!     // At this point:
//!     //   - .data / .bss / TCM sections have been relocated
//!     //   - FPU is enabled (mstatus.FS = Dirty)
//!     //   - L1 caches are initialized and invalidated
//!     //   - MIE bits are set
//!     //   - ROM patch table is resident in ITCM
//!     //   - ITCM / DTCM are available
//!     //   - WiFi / BT protocol stacks are NOT yet initialized
//!     loop {}
//! }
//! ```
//!
//! # Interrupt handling
//!
//! ## Weak-symbol override convention
//!
//! Interrupt handlers in `startup.S` are declared as **weak symbols** (`.weak`
//! directive). To handle an interrupt, define a function with the **exact same
//! name** in your Rust code:
//!
//! ```rust,ignore
//! #[unsafe(no_mangle)]
//! extern "C" fn TIMER_INT0() {
//!     // your ISR logic — no register save/restore, no mret
//! }
//! ```
//!
//! The handler is called by the assembly entry with the following environment
//! already set up:
//!
//! - A 272-byte unified `TaskContext` frame has been saved via
//!   `hisi_push_task_context`.
//! - `sp` points to the **IRQ stack** (`__irq_stack_top__`).
//! - Machine interrupts are disabled; the entry will re-enable them on exit.
//! - `mscratch` holds the saved frame pointer (see below).
//!
//! Your handler **must** follow these rules:
//!
//! - **Signature**: `extern "C" fn()` — no arguments, no return value.
//! - **No `mret`**: the assembly entry performs `mret` via `__hisi_resume_trap`.
//! - **No direct `mscratch` access**: `mscratch` is owned by the runtime.
//! - **Do not block** or wait on hardware indefinitely — the interrupt entry
//!   masks interrupts, and the epilogue expects a timely return.
//! - **If two modules define the same weak symbol**, the linker silently picks
//!   one — there is no duplicate-symbol error.
//!
//! ## `mscratch` register contract
//!
//! The `mscratch` CSR is **exclusively owned** by `hisi-riscv-rt`. It is used to
//! atomically swap the stack pointer between execution contexts via `csrrw`:
//!
//! ```text
//! Normal execution:   mscratch = __irq_stack_top__
//! During interrupt:   mscratch = saved TaskContext frame pointer
//! During exception:    mscratch = saved frame pointer (36-word save_all)
//! During NMI:         mscratch = saved frame pointer
//! ```
//!
//! **User code must never read or write `mscratch`.** Doing so silently corrupts
//! the stack-switch machinery and will cause undefined behaviour on the next
//! trap.
//!
//! ## Four-stack model
//!
//! The runtime allocates four independent stacks in SRAM (top-down, sizes
//! configurable via `memory.x`):
//!
//! | Stack | Symbol | Default size | Used by |
//! |---|---|---|---|
//! | User / main | `__stack_top__` | 8 KiB | application code |
//! | IRQ | `__irq_stack_top__` | 2 KiB | MIE interrupts (26-31) and local interrupts (32-91) |
//! | Exception | `__exc_stack_top__` | 2 KiB | synchronous exceptions (illegal insn, bus fault, …) |
//! | NMI | `__nmi_stack_top__` | 1 KiB | non-maskable interrupt |
//!
//! Each stack is independent — an overflow in one does not corrupt the others.
//! Stack sizes can be overridden in your `memory.x`:
//!
//! ```ld
//! __irq_stack_size = 0x1000;  /* 4 KiB */
//! ```
//!
//! # RTOS integration
//!
//! When an RTOS (e.g. `hisi-rtos`) is linked, it provides a **strong symbol**
//! for `__hisi_irq_epilogue`:
//!
//! ```rust,ignore
//! #[unsafe(no_mangle)]
//! extern "C" fn __hisi_irq_epilogue(frame: usize) -> usize {
//!     // frame: *mut TaskContext (272-byte unified frame on IRQ stack)
//!     // return: *mut TaskContext (same or different task's frame)
//! }
//! ```
//!
//! The epilogue may select a different task's frame to resume. If no RTOS is
//! linked, the default weak symbol returns `frame` unchanged (resume the
//! interrupted context).
//!
//! # Feature flags
//!
//! | Feature | Default | Chip | Effect |
//! |---|---|---|---|
//! | `bundled-memory-x` | on | all | Emit default `memory.x` via `build.rs` |
//! | `chip-ws63` | off | WS63 | WS63 startup adapter, `ws63-pac/rt` interrupts |
//! | `chip-bs21` | off | BS2X | BS2X startup adapter (requires `unstable`) |
//! | `boot-header` | off | WS63 | Embed 0x300-byte HiSilicon image header at `0x230000` |
//! | `ws63-bgle-32k` | off | WS63 | Use 32 KiB BGLE exchange memory profile (radio images) |
//! | `ws63-radio-main-stack-32k` | off | WS63 | Select the HIL-verified 32 KiB main-stack envelope for synchronous radio bootstrap |
//! | `startup-uart-trace` | off | WS63 | Emit 4-char markers (e.g. `RT2!`) on UART0 during startup |
//! | `riscv-rt-start-experiment` | off | WS63 | Delegate `_start` to `riscv-rt`; inject WS63 hooks (requires `unstable`) |
//! | `unstable` | off | all | Gate for experimental APIs (no stability guarantee) |
//!
//! # Safety invariants
//!
//! Users of this crate must uphold these contracts:
//!
//! - **`mscratch` exclusivity**: do not read or write `mscratch` in any
//!   application, HAL, or RTOS code.
//! - **Weak-symbol signature**: handlers must be `extern "C" fn()` with no
//!   arguments and no return value. Mismatched signatures cause UB.
//! - **No duplicate weak symbols**: if two translation units define the same
//!   handler name, the linker silently picks one — there is no error.
//! - **Stack sizing**: ensure each stack is large enough for its worst-case
//!   depth. The runtime does not perform stack overflow checking.
//! - **Chip-specific addresses are in chip adapter docs**: see the
//!   `chips::ws63` or `chips::bs2x` source modules for memory maps and startup
//!   sequences.
//!
//! # Linker conventions
//!
//! When `bundled-memory-x` is enabled (default), `hisi-riscv-rt` emits
//! `memory.x` via `build.rs`. If you provide a custom `memory.x`:
//!
//! - The four stack symbols (`__stack_top__`, `__irq_stack_top__`,
//!   `__exc_stack_top__`, `__nmi_stack_top__`) must be defined in the `.stacks`
//!   section of `layout.ld` in the correct relative order.
//! - `.text.entry` and `.text.runtime.init` must be placed at the start of the
//!   PROGRAM region.
//! - ITCM/DTCM ORIGIN values must match the target chip (see chip adapter docs).
//! - The `PRESERVE` region (256 bytes at end of SRAM) must not be removed —
//!   boot state is shared through it.

#![no_std]

#[cfg(all(feature = "boot-header", not(feature = "chip-ws63")))]
compile_error!("hisi-riscv-rt `boot-header` is WS63-only; enable `chip-ws63`");

#[cfg(all(feature = "chip-bs21", not(feature = "unstable")))]
compile_error!(
    "hisi-riscv-rt: BS2X runtime support is experimental; enable `unstable` with \
     `features = [\"chip-bs21\", \"unstable\"]`."
);

#[cfg(all(feature = "riscv-rt-start-experiment", not(feature = "chip-ws63")))]
compile_error!("hisi-riscv-rt `riscv-rt-start-experiment` is currently WS63-only");

#[cfg(all(feature = "riscv-rt-start-experiment", not(feature = "unstable")))]
compile_error!("hisi-riscv-rt `riscv-rt-start-experiment` is experimental; enable `unstable` with it");

#[cfg(all(feature = "ws63-radio-main-stack-32k", not(feature = "chip-ws63")))]
compile_error!("hisi-riscv-rt `ws63-radio-main-stack-32k` is WS63-only; enable `chip-ws63`");

// ---- Default startup path: custom asm/ws63/startup.S ----
#[cfg(all(
    feature = "chip-ws63",
    feature = "startup-uart-trace",
    not(feature = "riscv-rt-start-experiment")
))]
core::arch::global_asm!(concat!(
    ".set __hisi_chip_ws63, 1\n",
    ".set __hisi_startup_uart_trace, 1\n",
    include_str!("../asm/ws63/task_context.S"),
    include_str!("../asm/ws63/startup.S")
));

#[cfg(all(
    feature = "chip-ws63",
    not(feature = "startup-uart-trace"),
    not(feature = "riscv-rt-start-experiment")
))]
core::arch::global_asm!(concat!(
    ".set __hisi_chip_ws63, 1\n",
    include_str!("../asm/ws63/task_context.S"),
    include_str!("../asm/ws63/startup.S")
));

// ---- Experimental path: riscv-rt _start + WS63 overrides ----
// When riscv-rt-start-experiment is enabled, we defer to riscv-rt's _start
// (which handles GPR zero, GP/SP, .data/.bss, FPU) and provide:
//   - __pre_init: WS63 stack canary
//   - _setup_interrupts: WS63 mtvec + MIE bits
//   - trap_vector + all trap/IRQ handlers (WS63 direct-mode dispatch)
// The ROM/TCM/SRAM multi-region relocation is still handled by runtime_init,
// called from __pre_init via our Rust startup adapter.
// When riscv-rt-start-experiment is enabled, all WS63 startup assembly
// (__pre_init, _setup_interrupts, trap_vector, default handlers) is compiled
// via build.rs+cc into a separate .o to avoid LTO symbol conflicts with
// riscv-rt's weak defaults. See asm/ws63/startup_riscvrt.S.

#[cfg(all(feature = "chip-bs21", not(feature = "riscv-rt-start-experiment")))]
core::arch::global_asm!(concat!(
    ".set __hisi_chip_bs2x, 1\n",
    include_str!("../asm/ws63/task_context.S"),
    include_str!("../asm/ws63/startup.S")
));

pub mod rt_core;

pub(crate) mod chips;

#[cfg(feature = "boot-header")]
pub mod boot_header;

#[cfg(feature = "chip-bs21")]
#[cfg_attr(docsrs, doc(cfg(feature = "chip-bs21")))]
pub use bs2x_pac::interrupt;
/// WS63 interrupt enumeration and helpers.
///
/// Re-exports [`ws63_pac::interrupt`] which provides:
/// - [`ws63_pac::interrupt::ExternalInterrupt`] — all peripheral interrupt variants
///   (`TIMER_INT0`, `GPIO_INT0`, `SOFT_INT0`, …)
/// - [`ws63_pac::interrupt::cause()`] / [`ws63_pac::interrupt::try_cause()`] — read
///   the current trap cause
/// - [`ws63_pac::interrupt::enable()`] / [`ws63_pac::interrupt::disable()`] — global
///   interrupt mask (`mstatus.MIE`)
///
/// # WS63 interrupt tiers
///
/// | IRQ range | Mechanism | Examples |
/// |---|---|---|
/// | 26–31 | Standard RISC-V `mie` bits | TIMER0–2, RTC, I2C0–1 |
/// | 32+ | HiSilicon custom `LOCIEN` CSRs | GPIO, SPI, SOFT_INT, COEX, … |
///
/// See the `chips::ws63` source module for the full IRQ map and memory layout.
#[cfg(feature = "chip-ws63")]
#[cfg_attr(docsrs, doc(cfg(feature = "chip-ws63")))]
pub use ws63_pac::interrupt;

pub use rt_core::{entry, pre_init};

/// Prelude: commonly used runtime types.
///
/// Re-exports the three symbols most applications need:
///
/// | Symbol | Purpose |
/// |---|---|
/// | [`entry`] | `#[entry]` attribute — marks `fn main() -> !` |
/// | [`pre_init`] | `#[pre_init]` attribute — runs before `main` |
/// | `Interrupt` | All peripheral IRQ numbers for the selected chip |
pub mod prelude {
    pub use crate::{entry, pre_init};
    #[cfg(feature = "chip-bs21")]
    #[cfg_attr(docsrs, doc(cfg(feature = "chip-bs21")))]
    pub use bs2x_pac::interrupt::ExternalInterrupt as Interrupt;
    #[cfg(feature = "chip-ws63")]
    #[cfg_attr(docsrs, doc(cfg(feature = "chip-ws63")))]
    pub use ws63_pac::interrupt::ExternalInterrupt as Interrupt;
}

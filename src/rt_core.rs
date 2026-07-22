//! CPU-generic runtime facade.
//!
//! This module is the chip-neutral interface over `riscv-rt`. It should not grow
//! chip addresses, image-header layout, interrupt names, or board memory maps.
//! Those facts belong in chip startup adapters and linker fragments.

/// Marks `fn main() -> !` as the firmware entry point.
///
/// When control reaches `main()`, the startup adapter has already:
///
/// - Initialized shared RAM banks (dynamic memory config)
/// - Initialized and invalidated L1 caches
/// - Relocated all sections from flash to RAM (ROM data → DTCM,
///   TCM text → ITCM, TCM data → DTCM, SRAM text/data → SRAM)
/// - Zeroed BSS (ROM BSS, TCM BSS, SRAM BSS)
/// - Enabled the ROM patch table (if non-empty)
/// - Enabled the FPU (`mstatus.FS = Dirty`)
/// - Set `mie` bits for TIMER0-2, RTC, I2C0, I2C1
///
/// These specifics vary by chip; see the chip adapter module for the exact
/// sequence (e.g. [`chips::ws63`]).
///
/// # Chip-specific behaviour
///
/// See the [`chips`](crate::chips) module for chip-specific startup details.
pub use riscv_rt::entry;

/// Runs a function before [`entry`] — typically for custom early
/// initialization.
///
/// See [`entry`] for the environment that has already been set up by the
/// time `main()` is reached.
pub use riscv_rt::pre_init;

#[cfg(feature = "riscv-rt-start-experiment")]
#[doc(hidden)]
pub const RISCV_RT_START_EXPERIMENT: &str =
    "reserved: keep using the chip startup adapter until QEMU and HIL prove a riscv-rt _start path";

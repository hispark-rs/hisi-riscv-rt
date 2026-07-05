//! CPU-generic runtime facade.
//!
//! This module is the chip-neutral interface over `riscv-rt`. It should not grow
//! chip addresses, image-header layout, interrupt names, or board memory maps.
//! Those facts belong in chip startup adapters and linker fragments.

pub use riscv_rt::{entry, pre_init};

#[cfg(feature = "riscv-rt-start-experiment")]
#[doc(hidden)]
pub const RISCV_RT_START_EXPERIMENT: &str =
    "reserved: keep using the chip startup adapter until QEMU and HIL prove a riscv-rt _start path";

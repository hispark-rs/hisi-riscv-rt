//! # hisi-riscv-rt
//!
//! Runtime entry support for HiSilicon RISC-V firmware.
//!
//! The public crate interface is intentionally small: it re-exports the
//! `riscv-rt` entry attributes, the selected chip PAC's interrupt enum, and the
//! single-hart critical-section implementation configured through the `riscv`
//! crate. Chip-specific reset code, linker fragments, and image headers live
//! behind startup adapters. Chip interrupt symbols (`device.x`) are owned by the
//! selected PAC's `rt` feature.
//!
//! Current adapters:
//! - `chip-ws63`: WS63 startup, linker layout, `ws63-pac/rt` interrupt symbols,
//!   and optional link-time boot header.
//! - `chip-bs21` + `unstable`: BS2X compatibility path. This crate provides a
//!   BS21/BS2X default `memory.x`, a BS2X layout adapter, legacy startup, and
//!   `bs2x-pac/rt` provides `device.x`. BS20/custom boards should provide their
//!   own `memory.x`.
//!
//! Downstream binaries should link with `-Thisi-riscv-link.x`. The old
//! Downstream binaries should link with `-Thisi-riscv-link.x`.

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

#[cfg(feature = "chip-ws63")]
core::arch::global_asm!(concat!(
    ".set __hisi_chip_ws63, 1\n",
    include_str!("../asm/ws63/startup.S")
));

#[cfg(feature = "chip-bs21")]
core::arch::global_asm!(concat!(
    ".set __hisi_chip_bs2x, 1\n",
    include_str!("../asm/ws63/startup.S")
));

pub mod rt_core;

pub(crate) mod chips;

#[cfg(feature = "boot-header")]
pub mod boot_header;

#[cfg(feature = "chip-bs21")]
pub use bs2x_pac::interrupt;
#[cfg(feature = "chip-ws63")]
pub use ws63_pac::interrupt;

pub use rt_core::{entry, pre_init};

/// Prelude: commonly used runtime types.
pub mod prelude {
    pub use crate::{entry, pre_init};
    #[cfg(feature = "chip-bs21")]
    pub use bs2x_pac::interrupt::ExternalInterrupt as Interrupt;
    #[cfg(feature = "chip-ws63")]
    pub use ws63_pac::interrupt::ExternalInterrupt as Interrupt;
}

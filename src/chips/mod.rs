//! Chip startup adapters.
//!
//! Each adapter provides chip-specific reset code, linker fragments, memory
//! maps, interrupt tables, and optional image headers. See the adapter module
//! for your target chip:
//!
//! | Chip | Module | Feature | Status |
//! |---|---|---|---|
//! | WS63 | `ws63` | `chip-ws63` | stable |
//! | BS2X family | `bs2x` | `chip-bs21` | experimental (`unstable`) |

#[cfg(feature = "chip-bs21")]
pub(crate) mod bs2x;
pub(crate) mod hi3322;
#[cfg(any(feature = "chip-ws63", feature = "chip-bs21"))]
pub(crate) mod ws63;

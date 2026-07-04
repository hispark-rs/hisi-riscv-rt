//! Chip startup adapters.

#[cfg(feature = "chip-bs21")]
pub(crate) mod bs2x;
pub(crate) mod hi3322;
#[cfg(any(feature = "chip-ws63", feature = "chip-bs21"))]
pub(crate) mod ws63;

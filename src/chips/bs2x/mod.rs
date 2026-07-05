//! BS2X compatibility startup adapter.
//!
//! BS20/BS21 examples currently provide their own `memory.x`, and `bs2x-pac/rt`
//! provides the chip interrupt `device.x`. The reset assembly and linker layout
//! are still shared with the legacy WS63/M-core path. This module marks the real
//! adapter seam so a measured BS2X-specific startup/linker layout can replace
//! that compatibility path without changing the public crate interface.

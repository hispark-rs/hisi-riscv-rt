//! WS63 startup adapter.
//!
//! This adapter owns the current reset path, trap dispatch, cache setup, and
//! relocation code used by WS63 firmware. BS2X temporarily reuses this legacy
//! startup implementation while supplying its own memory map and interrupt
//! `device.x`; keep new WS63-only assumptions documented here or behind
//! `feature = "chip-ws63"`.

pub(crate) mod startup;

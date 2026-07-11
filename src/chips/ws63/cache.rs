//! WS63 cache setup required by the vendor application runtime.
//!
//! Flashboot leaves the cache geometry selected but the caches disabled. The
//! WS63 ROM contains 48-bit `l.li` instructions; executing that ROM before the
//! application runtime enables and invalidates the instruction cache can split
//! the final instruction parcel into a separate load. Keep this sequence in
//! lockstep with the vendor `cpu_cache_init()` implementation.

use core::arch::asm;

const CACHE_INVALIDATE_ALL: usize = 1 << 2;
const ICACHE_32_KIB_ENABLE: usize = 6 | 1;
const ICACHE_PREFETCH_ONE_LINE: usize = 1;
const DCACHE_4_KIB_ENABLE: usize = 1;

/// Invalidate and enable the WS63 instruction and data caches.
///
/// # Safety
///
/// Must run exactly once during early WS63 startup, before application data is
/// relocated or vendor ROM code is called.
#[unsafe(no_mangle)]
#[unsafe(link_section = ".text.runtime.init")]
pub(super) unsafe extern "C" fn __hisi_ws63_cache_init() {
    unsafe {
        asm!(
            "csrw 0x7c2, {invalidate_all}",
            "fence",
            "csrw 0x7c3, {invalidate_all}",
            "fence",
            "csrw 0x7c0, {icache_ctl}",
            "csrw 0x7c6, {icache_prefetch}",
            "csrw 0x7c1, {dcache_ctl}",
            invalidate_all = in(reg) CACHE_INVALIDATE_ALL,
            icache_ctl = in(reg) ICACHE_32_KIB_ENABLE,
            icache_prefetch = in(reg) ICACHE_PREFETCH_ONE_LINE,
            dcache_ctl = in(reg) DCACHE_4_KIB_ENABLE,
            options(nostack),
        );
    }
}

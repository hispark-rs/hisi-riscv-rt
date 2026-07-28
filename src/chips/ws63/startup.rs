//! Runtime initialization for WS63.
//!
//! Called from assembly startup before jumping to `main()`.
//! Handles:
//! - Data section copy from flash to SRAM/DTCM
//! - BSS zeroing
//! - ROM data relocation (DTCM)
//! - ROM BSS clearing
//! - TCM text/data copy
//! - FPU initialization

/// Called by startup assembly after basic CPU initialization.
///
/// # Safety
/// Called only once at boot, before main().
#[unsafe(no_mangle)]
#[unsafe(link_section = ".text.runtime.init")]
pub unsafe extern "C" fn runtime_init() -> ! {
    startup_mark4(b'R', b'T', b'2', b'!');

    // The configurable banks backing ITCM/DTCM must be assigned before either
    // cache setup or relocation. This is the vendor runtime's dyn_mem_cfg step.
    #[cfg(feature = "chip-ws63")]
    unsafe {
        super::memory::__hisi_ws63_shared_ram_init()
    };

    // Clear caller-owned NOLOAD arenas while D-cache is still disabled. This
    // makes the one-shot claim state deterministic even when the arena is much
    // larger than the 4 KiB data cache.
    #[cfg(feature = "chip-ws63")]
    unsafe {
        zero_shared_arenas()
    };

    // Match the vendor runtime: invalidate and enable caches before any
    // application relocation or vendor ROM call.
    unsafe { super::cache::__hisi_ws63_cache_init() };

    // Relocate sections from flash to RAM
    unsafe { relocate_data() };

    // Zero BSS
    unsafe { zero_bss() };

    // The post-link generated table is now resident in ITCM. Enable the
    // controller only when the table contains at least one ROM redirection.
    #[cfg(feature = "chip-ws63")]
    unsafe {
        super::rom_patch::__hisi_ws63_rom_patch_enable()
    };

    startup_mark4(b'R', b'T', b'3', b'!');

    // Re-enable machine interrupts (disabled by startup.S for init)
    // MIE bits 26-31: TIMER0, TIMER1, TIMER2, RTC, I2C0, I2C1
    // Peripherals further enable their own interrupt sources via PLIC.
    unsafe {
        // Re-enable machine interrupts: MEIE(11) + MTIE(7) + MSIE(3)
        // Use csrs with register (csrsi immediate is 5-bit only)
        core::arch::asm!(
            "li t0, 0x888",
            "csrs mie, t0",
            out("t0") _,
            options(nomem, nostack),
        );
    }

    // Call user main - this never returns
    unsafe extern "Rust" {
        fn main() -> !;
    }
    startup_mark4(b'R', b'T', b'4', b'!');
    unsafe { main() };
}

#[cfg(feature = "startup-uart-trace")]
#[inline(always)]
fn startup_putc(b: u8) {
    const DATA: *mut u16 = 0x4401_0004 as *mut u16;
    const ST: *const u16 = 0x4401_0044 as *const u16;
    const TX_FULL: u16 = 1 << 0;
    const TX_EMPTY: u16 = 1 << 1;
    unsafe {
        while core::ptr::read_volatile(ST) & TX_FULL != 0 {
            core::hint::spin_loop();
        }
        core::ptr::write_volatile(DATA, b as u16);
        while core::ptr::read_volatile(ST) & TX_EMPTY == 0 {
            core::hint::spin_loop();
        }
    }
}

#[cfg(feature = "startup-uart-trace")]
#[inline(always)]
fn startup_mark4(a: u8, b: u8, c: u8, d: u8) {
    startup_putc(a);
    startup_putc(b);
    startup_putc(c);
    startup_putc(d);
    startup_putc(b'\r');
    startup_putc(b'\n');
}

#[cfg(feature = "startup-uart-trace")]
#[unsafe(no_mangle)]
pub extern "C" fn __hisi_startup_trace_trap(mcause: usize, mepc: usize, mtval: usize, ccause: usize) {
    startup_trace_kv(b"MC=", mcause);
    startup_trace_kv(b"EP=", mepc);
    startup_trace_kv(b"TV=", mtval);
    startup_trace_kv(b"CC=", ccause);
}

#[cfg(feature = "startup-uart-trace")]
fn startup_trace_kv(prefix: &[u8; 3], value: usize) {
    startup_putc(prefix[0]);
    startup_putc(prefix[1]);
    startup_putc(prefix[2]);
    startup_putc(b'0');
    startup_putc(b'x');
    let mut shift = usize::BITS - 4;
    loop {
        let nibble = ((value >> shift) & 0xf) as u8;
        startup_putc(if nibble < 10 {
            b'0' + nibble
        } else {
            b'a' + (nibble - 10)
        });
        if shift == 0 {
            break;
        }
        shift -= 4;
    }
    startup_putc(b'\r');
    startup_putc(b'\n');
}

#[cfg(not(feature = "startup-uart-trace"))]
#[inline(always)]
fn startup_mark4(_a: u8, _b: u8, _c: u8, _d: u8) {}

#[inline(always)]
fn range_len(begin: usize, end: usize) -> usize {
    end.saturating_sub(begin)
}

/// Copy initialized data sections from flash to RAM.
///
/// Copies ROM data to DTCM, TCM text/data to ITCM/DTCM,
/// and SRAM text/data to SRAM.
#[unsafe(link_section = ".text.runtime.init")]
unsafe fn relocate_data() {
    unsafe extern "C" {
        // ROM data: flash → DTCM
        static mut __rom_data_begin__: u32;
        static mut __rom_data_end__: u32;
        static mut __rom_data_load__: u32;

        // Wi-Fi ROM data: flash → ABI-fixed DTCM window (WS63 only)
        #[cfg(feature = "chip-ws63")]
        static mut __wifi_rom_data_begin__: u32;
        #[cfg(feature = "chip-ws63")]
        static mut __wifi_rom_data_end__: u32;
        #[cfg(feature = "chip-ws63")]
        static mut __wifi_rom_data_load__: u32;

        // Mask-ROM instruction patch table: flash → ITCM
        static mut __rom_patch_begin__: u32;
        static mut __rom_patch_end__: u32;
        static mut __rom_patch_load__: u32;

        // ROM BSS: zero in DTCM
        static mut __rom_bss_begin__: u32;
        static mut __rom_bss_end__: u32;

        // TCM text: flash → ITCM
        static mut __tcm_text_begin__: u32;
        static mut __tcm_text_end__: u32;
        static mut __tcm_text_load__: u32;

        // TCM data: flash → DTCM
        static mut __tcm_data_begin__: u32;
        static mut __tcm_data_end__: u32;
        static mut __tcm_data_load__: u32;

        // TCM BSS: zero in DTCM
        static mut __tcm_bss_begin__: u32;
        static mut __tcm_bss_end__: u32;

        // SRAM text: flash → SRAM
        static mut __sram_text_begin__: u32;
        static mut __sram_text_end__: u32;
        static mut __sram_text_load__: u32;

        // Data: flash → SRAM
        static mut __data_begin__: u32;
        static mut __data_end__: u32;
        static mut __data_load__: u32;

        // BSS: zero in SRAM
        static mut __bss_begin__: u32;
        static mut __bss_end__: u32;
    }

    unsafe {
        startup_mark4(b'R', b'D', b'0', b'!');
        let begin = &raw const __rom_patch_begin__ as usize;
        let end = &raw const __rom_patch_end__ as usize;
        let count = range_len(begin, end);
        if count > 0 {
            core::ptr::copy_nonoverlapping(
                &raw const __rom_patch_load__ as *const u8,
                &raw mut __rom_patch_begin__ as *mut u8,
                count,
            );
        }
        // Copy ROM data to DTCM
        let begin = &raw const __rom_data_begin__ as usize;
        let end = &raw const __rom_data_end__ as usize;
        let count = range_len(begin, end);
        if count > 0 {
            core::ptr::copy_nonoverlapping(
                &raw const __rom_data_load__ as *const u8,
                &raw mut __rom_data_begin__ as *mut u8,
                count,
            );
        }
        #[cfg(feature = "chip-ws63")]
        {
            let begin = &raw const __wifi_rom_data_begin__ as usize;
            let end = &raw const __wifi_rom_data_end__ as usize;
            let count = range_len(begin, end);
            if count > 0 {
                core::ptr::copy_nonoverlapping(
                    &raw const __wifi_rom_data_load__ as *const u8,
                    &raw mut __wifi_rom_data_begin__ as *mut u8,
                    count,
                );
            }
        }
        startup_mark4(b'R', b'D', b'1', b'!');
        // Zero ROM BSS in DTCM
        let begin = &raw const __rom_bss_begin__ as usize;
        let end = &raw const __rom_bss_end__ as usize;
        let bss_count = range_len(begin, end);
        if bss_count > 0 {
            core::ptr::write_bytes(&raw mut __rom_bss_begin__ as *mut u8, 0, bss_count);
        }
        startup_mark4(b'R', b'D', b'2', b'!');

        // Copy TCM text to ITCM
        let begin = &raw const __tcm_text_begin__ as usize;
        let end = &raw const __tcm_text_end__ as usize;
        let count = range_len(begin, end);
        if count > 0 {
            core::ptr::copy_nonoverlapping(
                &raw const __tcm_text_load__ as *const u8,
                &raw mut __tcm_text_begin__ as *mut u8,
                count,
            );
        }
        startup_mark4(b'R', b'D', b'3', b'!');
        // Copy TCM data to DTCM
        let begin = &raw const __tcm_data_begin__ as usize;
        let end = &raw const __tcm_data_end__ as usize;
        let count = range_len(begin, end);
        if count > 0 {
            core::ptr::copy_nonoverlapping(
                &raw const __tcm_data_load__ as *const u8,
                &raw mut __tcm_data_begin__ as *mut u8,
                count,
            );
        }
        startup_mark4(b'R', b'D', b'4', b'!');
        // Zero TCM BSS in DTCM
        let begin = &raw const __tcm_bss_begin__ as usize;
        let end = &raw const __tcm_bss_end__ as usize;
        let bss_count = range_len(begin, end);
        if bss_count > 0 {
            core::ptr::write_bytes(&raw mut __tcm_bss_begin__ as *mut u8, 0, bss_count);
        }
        startup_mark4(b'R', b'D', b'5', b'!');

        // Copy SRAM text to SRAM
        let begin = &raw const __sram_text_begin__ as usize;
        let end = &raw const __sram_text_end__ as usize;
        let count = range_len(begin, end);
        if count > 0 {
            core::ptr::copy_nonoverlapping(
                &raw const __sram_text_load__ as *const u8,
                &raw mut __sram_text_begin__ as *mut u8,
                count,
            );
        }
        startup_mark4(b'R', b'D', b'6', b'!');
        // Copy .data to SRAM
        let begin = &raw const __data_begin__ as usize;
        let end = &raw const __data_end__ as usize;
        let count = range_len(begin, end);
        if count > 0 {
            core::ptr::copy_nonoverlapping(
                &raw const __data_load__ as *const u8,
                &raw mut __data_begin__ as *mut u8,
                count,
            );
        }
        startup_mark4(b'R', b'D', b'7', b'!');
    }
}

/// Zero the BSS section in SRAM.
#[unsafe(link_section = ".text.runtime.init")]
unsafe fn zero_bss() {
    unsafe extern "C" {
        static mut __bss_begin__: u32;
        static mut __bss_end__: u32;
    }

    unsafe {
        startup_mark4(b'Z', b'B', b'0', b'!');
        let begin = &raw const __bss_begin__ as usize;
        let end = &raw const __bss_end__ as usize;
        let count = range_len(begin, end);
        if count > 0 {
            core::ptr::write_bytes(&raw mut __bss_begin__ as *mut u8, 0, count);
        }
        startup_mark4(b'Z', b'B', b'1', b'!');
    }
}

#[unsafe(link_section = ".text.runtime.init")]
#[cfg(feature = "chip-ws63")]
unsafe fn zero_shared_arenas() {
    unsafe extern "C" {
        static mut __hisi_shared_arenas_start__: u32;
        static mut __hisi_shared_arenas_end__: u32;
    }

    unsafe {
        let begin = &raw const __hisi_shared_arenas_start__ as usize;
        let end = &raw const __hisi_shared_arenas_end__ as usize;
        let count = range_len(begin, end);
        if count > 0 {
            core::ptr::write_bytes(&raw mut __hisi_shared_arenas_start__ as *mut u8, 0, count);
        }
    }
}

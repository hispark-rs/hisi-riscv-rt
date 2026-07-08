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
    // Relocate sections from flash to RAM
    unsafe { relocate_data() };

    // Zero BSS
    unsafe { zero_bss() };

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
    unsafe { main() };
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
        // Copy ROM data to DTCM
        let count = &raw const __rom_data_end__ as usize - &raw const __rom_data_begin__ as usize;
        if count > 0 {
            core::ptr::copy_nonoverlapping(
                &raw const __rom_data_load__ as *const u8,
                &raw mut __rom_data_begin__ as *mut u8,
                count,
            );
        }
        // Zero ROM BSS in DTCM
        let bss_count = &raw const __rom_bss_end__ as usize - &raw const __rom_bss_begin__ as usize;
        if bss_count > 0 {
            core::ptr::write_bytes(&raw mut __rom_bss_begin__ as *mut u8, 0, bss_count);
        }

        // Copy TCM text to ITCM
        let count = &raw const __tcm_text_end__ as usize - &raw const __tcm_text_begin__ as usize;
        if count > 0 {
            core::ptr::copy_nonoverlapping(
                &raw const __tcm_text_load__ as *const u8,
                &raw mut __tcm_text_begin__ as *mut u8,
                count,
            );
        }
        // Copy TCM data to DTCM
        let count = &raw const __tcm_data_end__ as usize - &raw const __tcm_data_begin__ as usize;
        if count > 0 {
            core::ptr::copy_nonoverlapping(
                &raw const __tcm_data_load__ as *const u8,
                &raw mut __tcm_data_begin__ as *mut u8,
                count,
            );
        }
        // Zero TCM BSS in DTCM
        let bss_count = &raw const __tcm_bss_end__ as usize - &raw const __tcm_bss_begin__ as usize;
        if bss_count > 0 {
            core::ptr::write_bytes(&raw mut __tcm_bss_begin__ as *mut u8, 0, bss_count);
        }

        // Copy SRAM text to SRAM
        let count = &raw const __sram_text_end__ as usize - &raw const __sram_text_begin__ as usize;
        if count > 0 {
            core::ptr::copy_nonoverlapping(
                &raw const __sram_text_load__ as *const u8,
                &raw mut __sram_text_begin__ as *mut u8,
                count,
            );
        }
        // Copy .data to SRAM
        let count = &raw const __data_end__ as usize - &raw const __data_begin__ as usize;
        if count > 0 {
            core::ptr::copy_nonoverlapping(
                &raw const __data_load__ as *const u8,
                &raw mut __data_begin__ as *mut u8,
                count,
            );
        }
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
        let count = &raw const __bss_end__ as usize - &raw const __bss_begin__ as usize;
        if count > 0 {
            core::ptr::write_bytes(&raw mut __bss_begin__ as *mut u8, 0, count);
        }
    }
}

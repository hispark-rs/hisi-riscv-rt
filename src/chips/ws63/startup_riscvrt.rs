//! WS63 post-init for the riscv-rt-start-experiment path.
//!
//! riscv-rt's `_start` handles GP/SP/FP, .data/.bss, FPU.
//! `__pre_init` (in startup_riscvrt.S) handles stack canary.
//! `_setup_interrupts` (in startup_riscvrt.S) calls this function
//! after .data/.bss/FPU are ready, then sets mtvec.

/// ROM/TCM/SRAM multi-region relocation + MIE enable.
///
/// Called from `_setup_interrupts` (assembly) after riscv-rt's `_start`
/// has finished `.data`/`.bss`/FPU init. Returns normally so the
/// caller can set mtvec before the `j main` in riscv-rt's `_start`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn runtime_init_riscvrt() {
    unsafe {
        super::memory::__hisi_ws63_shared_ram_init();
        super::cache::__hisi_ws63_cache_init();
        relocate_data();
        zero_extra_bss();
        core::arch::asm!(
            "li t0, 0x888",
            "csrs mie, t0",
            out("t0") _,
            options(nomem, nostack),
        );
    }
}

unsafe fn relocate_data() {
    unsafe extern "C" {
        static mut __rom_data_begin__: u32;
        static mut __rom_data_end__: u32;
        static mut __rom_data_load__: u32;
        static mut __wifi_rom_data_begin__: u32;
        static mut __wifi_rom_data_end__: u32;
        static mut __wifi_rom_data_load__: u32;
        static mut __tcm_text_begin__: u32;
        static mut __tcm_text_end__: u32;
        static mut __tcm_text_load__: u32;
        static mut __tcm_data_begin__: u32;
        static mut __tcm_data_end__: u32;
        static mut __tcm_data_load__: u32;
        static mut __sram_text_begin__: u32;
        static mut __sram_text_end__: u32;
        static mut __sram_text_load__: u32;
    }

    unsafe {
        macro_rules! copy_region {
            ($load:ident, $begin:ident, $end:ident) => {
                let count = &raw const $end as usize - &raw const $begin as usize;
                if count > 0 {
                    core::ptr::copy_nonoverlapping(&raw const $load as *const u8, &raw mut $begin as *mut u8, count);
                }
            };
        }

        copy_region!(__rom_data_load__, __rom_data_begin__, __rom_data_end__);
        copy_region!(__wifi_rom_data_load__, __wifi_rom_data_begin__, __wifi_rom_data_end__);
        copy_region!(__tcm_text_load__, __tcm_text_begin__, __tcm_text_end__);
        copy_region!(__tcm_data_load__, __tcm_data_begin__, __tcm_data_end__);
        copy_region!(__sram_text_load__, __sram_text_begin__, __sram_text_end__);
    }
}

unsafe fn zero_extra_bss() {
    unsafe extern "C" {
        static mut __rom_bss_begin__: u32;
        static mut __rom_bss_end__: u32;
        static mut __tcm_bss_begin__: u32;
        static mut __tcm_bss_end__: u32;
    }

    unsafe {
        macro_rules! zero_region {
            ($begin:ident, $end:ident) => {
                let count = &raw const $end as usize - &raw const $begin as usize;
                if count > 0 {
                    core::ptr::write_bytes(&raw mut $begin as *mut u8, 0, count);
                }
            };
        }

        zero_region!(__rom_bss_begin__, __rom_bss_end__);
        zero_region!(__tcm_bss_begin__, __tcm_bss_end__);
    }
}

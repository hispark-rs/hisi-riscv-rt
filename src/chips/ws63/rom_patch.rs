//! WS63 mask-ROM instruction patch controller setup.

use core::arch::asm;

const INSTRUCTION_COMPARE_COUNT: usize = 192;
const COMPARE_HEADER_WORDS: usize = 3;

/// Load the post-link generated comparison table into the hardware controller.
///
/// A zero entry count leaves the controller untouched, so ordinary WS63
/// firmware pays no behavioral cost for reserving the mask-ROM ABI prefix.
///
/// # Safety
///
/// Must run once after `.patch` has been relocated to ITCM and before any code
/// that depends on a redirected mask-ROM entry point.
#[unsafe(no_mangle)]
#[unsafe(link_section = ".text.runtime.init")]
pub(super) unsafe extern "C" fn __hisi_ws63_rom_patch_enable() {
    unsafe extern "C" {
        static __rom_patch_begin__: u32;
        static __rom_patch_cmp_begin__: u32;
    }

    let remap = &raw const __rom_patch_begin__;
    let compare = &raw const __rom_patch_cmp_begin__;
    let entry_count = unsafe { compare.add(2).read() } as usize;
    if entry_count == 0 || entry_count > INSTRUCTION_COMPARE_COUNT {
        return;
    }

    // SAFETY: this chip adapter owns the one-time early-boot transition of the
    // WS63 patch controller. The complete register block is SVD/PAC modeled.
    let registers = unsafe { &*ws63_pac::RiscvPatch::ptr() };

    registers.flpctrl().write(|w| {
        w.enable()
            .set_bit()
            .write_protect()
            .clear_bit()
            .outside_1m()
            .set_bit()
            .load_compare0_enable()
            .clear_bit()
            .load_compare1_enable()
            .clear_bit()
    });

    for (index, register) in registers.flpiacmp_iter().enumerate() {
        let value = unsafe { compare.add(COMPARE_HEADER_WORDS + index).read() };
        register.write(|w| unsafe { w.bits(value) });
    }
    registers.flprmp().write(|w| unsafe { w.bits(remap as u32) });
    registers.flpctrl().write(|w| {
        w.enable()
            .set_bit()
            .write_protect()
            .set_bit()
            .outside_1m()
            .set_bit()
            .load_compare0_enable()
            .clear_bit()
            .load_compare1_enable()
            .clear_bit()
    });

    // Match the vendor `riscv_patch_init` ordering barrier after write protect.
    unsafe { asm!("fence iorw, iorw", options(nostack)) };
}

//! WS63 configurable shared-RAM setup required before TCM relocation.

use core::arch::asm;

/// Select the vendor default Wi-Fi memory shape before touching ITCM/DTCM.
///
/// RAM5-RAM9/RAM12 remain packet RAM, RAM10 becomes DTCM, and RAM11 becomes
/// ITCM. This mirrors `fbb_ws63`'s `dyn_mem_cfg()` default branch.
///
/// # Safety
///
/// Must execute from flash exactly once during startup, before any code or data
/// is placed in the configurable TCM banks.
#[unsafe(no_mangle)]
#[unsafe(link_section = ".text.runtime.init")]
pub(super) unsafe extern "C" fn __hisi_ws63_shared_ram_init() {
    let share = unsafe { &*ws63_pac::ShareMemCtl::ptr() };
    let bt_em = unsafe { &*ws63_pac::BtEmCtl::ptr() };

    share.cfg_ram_cken().modify(|_, w| {
        // SAFETY: zero gates the complete 14-bit configurable-bank field.
        unsafe { w.share_ram_cken().bits(0) }
    });
    bt_em.em_gt_mode().modify(|_, w| w.enable().set_bit());
    fence_io();

    share.cfg_ram_sel().modify(|_, w| {
        // SAFETY: all values are documented two-bit bank selections.
        unsafe {
            w.ram12_sel()
                .clear_bit()
                .ram11_sel()
                .bits(2)
                .ram10_sel()
                .bits(3)
                .ram9_sel()
                .bits(0)
                .ram8_sel()
                .bits(0)
                .ram7_sel()
                .bits(0)
                .ram6_sel()
                .bits(0)
                .ram5_sel()
                .bits(0)
        }
    });

    share.cfg_ram_cken().modify(|_, w| {
        // SAFETY: 0x3fff enables every bit in the 14-bit field.
        unsafe { w.share_ram_cken().bits(0x3fff) }
    });
    bt_em.em_gt_mode().modify(|_, w| w.enable().clear_bit());
    fence_io();
}

#[inline(always)]
fn fence_io() {
    // SAFETY: orders device writes around a live RAM-bank ownership change.
    unsafe { asm!("fence iorw, iorw", options(nostack)) };
}

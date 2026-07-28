#![no_main]
#![no_std]

use hisi_riscv_rt::entry;

#[cfg(feature = "chip-ws63")]
#[used]
#[unsafe(link_section = ".hisi.shared-arena")]
static SHARED_ARENA_LINK_SMOKE: [u8; 64] = [0; 64];

#[entry]
fn main() -> ! {
    loop {
        core::hint::spin_loop();
    }
}

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo<'_>) -> ! {
    loop {
        core::hint::spin_loop();
    }
}

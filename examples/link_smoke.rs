#![no_main]
#![no_std]

use hisi_riscv_rt::entry;

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

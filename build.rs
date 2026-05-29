/// Build script for ws63-rt.
///
/// Copies linker scripts and device.x to OUT_DIR so they can be
/// referenced by the linker and runtime code.
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

fn main() {
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());

    // Copy linker scripts for the linker
    let memory_x = Path::new("memory.x");
    let layout_ld = Path::new("layout.ld");
    let device_x = Path::new("device.x");
    let symbols_x = Path::new("riscv-rt-symbols.x");

    println!("cargo:rerun-if-changed=memory.x");
    println!("cargo:rerun-if-changed=layout.ld");
    println!("cargo:rerun-if-changed=device.x");
    println!("cargo:rerun-if-changed=riscv-rt-symbols.x");
    println!("cargo:rerun-if-changed=asm/startup.S");

    // Place linker scripts in OUT_DIR and use absolute paths
    let layout_out = out_dir.join("layout.ld");
    let memory_out = out_dir.join("memory.x");
    let device_out = out_dir.join("device.x");
    let symbols_out = out_dir.join("riscv-rt-symbols.x");

    fs::copy(memory_x, &memory_out).expect("Failed to copy memory.x");
    fs::copy(layout_ld, &layout_out).expect("Failed to copy layout.ld");
    fs::copy(device_x, &device_out).expect("Failed to copy device.x");
    fs::copy(symbols_x, &symbols_out).expect("Failed to copy riscv-rt-symbols.x");

    // Load linker scripts in order: layout first, then memory, then device, then symbols (LAST)
    println!("cargo:rustc-link-arg=-T{}", layout_out.display());
    println!("cargo:rustc-link-arg=-T{}", memory_out.display());
    println!("cargo:rustc-link-arg=-T{}", device_out.display());
    println!("cargo:rustc-link-arg=-T{}", symbols_out.display());

    // (startup.S is now included via global_asm! in lib.rs)

    // Set RISC-V base ISA for riscv-rt (rv32i — no atomic extension)
    println!("cargo:rustc-env=RISCV_RT_BASE_ISA=rv32i");

    // Custom cfg for WS63-specific code
    println!("cargo:rustc-cfg=target_chip=\"ws63\"");
}

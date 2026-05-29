/// Build script for ws63-rt.
///
/// Copies linker scripts and device.x to OUT_DIR so they can be
/// referenced by the linker and runtime code.
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

fn main() {
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());

    // Copy memory.x and layout.ld for the linker
    let memory_x = Path::new("memory.x");
    let layout_ld = Path::new("layout.ld");
    let device_x = Path::new("device.x");

    println!("cargo:rerun-if-changed=memory.x");
    println!("cargo:rerun-if-changed=layout.ld");
    println!("cargo:rerun-if-changed=device.x");
    println!("cargo:rerun-if-changed=asm/startup.S");

    // Place linker scripts in OUT_DIR
    fs::copy(memory_x, out_dir.join("memory.x")).expect("Failed to copy memory.x");
    fs::copy(layout_ld, out_dir.join("layout.ld")).expect("Failed to copy layout.ld");
    fs::copy(device_x, out_dir.join("device.x")).expect("Failed to copy device.x");

    // Set linker script path for rustc
    println!("cargo:rustc-link-arg=-Tlayout.ld");
    println!("cargo:rustc-link-arg=-Tmemory.x");
    println!("cargo:rustc-link-arg=-Tdevice.x");

    // Linker search path for OUT_DIR
    println!("cargo:rustc-link-search={}", out_dir.display());

    // Assembly file
    let asm_path = Path::new("asm/startup.S");
    if asm_path.exists() {
        println!("cargo:rustc-link-arg={}", asm_path.display());
    }

    // Set RISC-V base ISA for riscv-rt (rv32i — no atomic extension)
    println!("cargo:rustc-env=RISCV_RT_BASE_ISA=rv32i");

    // Custom cfg for WS63-specific code
    println!("cargo:rustc-cfg=target_chip=\"ws63\"");
}

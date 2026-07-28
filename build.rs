use std::env;
use std::fs;
use std::path::{Path, PathBuf};

fn main() {
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());

    let chip_ws63 = env::var_os("CARGO_FEATURE_CHIP_WS63").is_some();
    let chip_bs21 = env::var_os("CARGO_FEATURE_CHIP_BS21").is_some();
    let bundled_memory = env::var_os("CARGO_FEATURE_BUNDLED_MEMORY_X").is_some();
    let boot_header_enabled = env::var_os("CARGO_FEATURE_BOOT_HEADER").is_some();
    let riscv_rt_start_experiment = env::var_os("CARGO_FEATURE_RISCV_RT_START_EXPERIMENT").is_some();
    let ws63_bgle_32k = env::var_os("CARGO_FEATURE_WS63_BGLE_32K").is_some();
    let ws63_radio_main_stack_32k = env::var_os("CARGO_FEATURE_WS63_RADIO_MAIN_STACK_32K").is_some();
    let unstable = env::var_os("CARGO_FEATURE_UNSTABLE").is_some();

    if chip_ws63 && chip_bs21 {
        panic!("hisi-riscv-rt features `chip-ws63` and `chip-bs21` are mutually exclusive");
    }
    if chip_bs21 && !unstable {
        panic!("hisi-riscv-rt `chip-bs21` is experimental; enable `unstable` with it");
    }
    if boot_header_enabled && !chip_ws63 {
        panic!("hisi-riscv-rt `boot-header` is WS63-only; enable `chip-ws63` or disable it");
    }
    if riscv_rt_start_experiment && !chip_ws63 {
        panic!("hisi-riscv-rt `riscv-rt-start-experiment` is currently WS63-only");
    }
    if riscv_rt_start_experiment && !unstable {
        panic!("hisi-riscv-rt `riscv-rt-start-experiment` is experimental; enable `unstable` with it");
    }
    if ws63_radio_main_stack_32k && !chip_ws63 {
        panic!(
            "hisi-riscv-rt `ws63-radio-main-stack-32k` is WS63-only; \
             enable `chip-ws63` or disable it"
        );
    }

    let ws63_memory_x = Path::new("linker/ws63/memory.x");
    let ws63_layout_ld = if riscv_rt_start_experiment {
        Path::new("linker/ws63/layout_riscvrt.ld")
    } else {
        Path::new("linker/ws63/layout.ld")
    };
    let ws63_boot_header_x = Path::new("linker/ws63/boot-header.x");
    let bs2x_memory_x = Path::new("linker/bs2x/memory.x");
    let bs2x_layout_ld = Path::new("linker/bs2x/layout.ld");
    let bs2x_boot_header_x = Path::new("linker/bs2x/boot-header.x");
    let symbols_x = Path::new("linker/common/riscv-rt-symbols.x");
    let startup_s = Path::new("asm/ws63/startup.S");
    let task_context_s = Path::new("asm/ws63/task_context.S");

    println!("cargo:rerun-if-changed={}", ws63_memory_x.display());
    println!("cargo:rerun-if-changed={}", ws63_layout_ld.display());
    println!("cargo:rerun-if-changed={}", ws63_boot_header_x.display());
    println!("cargo:rerun-if-changed={}", bs2x_memory_x.display());
    println!("cargo:rerun-if-changed={}", bs2x_layout_ld.display());
    println!("cargo:rerun-if-changed={}", bs2x_boot_header_x.display());
    println!("cargo:rerun-if-changed={}", symbols_x.display());
    println!("cargo:rerun-if-changed={}", startup_s.display());
    println!("cargo:rerun-if-changed={}", task_context_s.display());
    let startup_riscvrt_s = Path::new("asm/ws63/startup_riscvrt.S");
    println!("cargo:rerun-if-changed={}", startup_riscvrt_s.display());

    let layout_out = out_dir.join("layout.ld");
    let memory_out = out_dir.join("memory.x");
    let stale_device_out = out_dir.join("device.x");
    let symbols_out = out_dir.join("riscv-rt-symbols.x");
    let boot_header_out = out_dir.join("boot-header.x");

    let selected_memory_x = if chip_ws63 {
        Some(ws63_memory_x)
    } else if chip_bs21 {
        Some(bs2x_memory_x)
    } else {
        None
    };
    let selected_layout_ld = if chip_ws63 {
        Some(ws63_layout_ld)
    } else if chip_bs21 {
        Some(bs2x_layout_ld)
    } else {
        None
    };

    if bundled_memory {
        if let Some(memory_x) = selected_memory_x {
            fs::copy(memory_x, &memory_out).expect("Failed to copy selected memory.x");
        } else if memory_out.exists() {
            fs::remove_file(&memory_out).expect("Failed to remove stale memory.x");
        }
    } else if memory_out.exists() {
        fs::remove_file(&memory_out).expect("Failed to remove stale memory.x");
    }

    if let Some(layout_ld) = selected_layout_ld {
        fs::copy(layout_ld, &layout_out).expect("Failed to copy selected layout.ld");
    } else if layout_out.exists() {
        fs::remove_file(&layout_out).expect("Failed to remove stale layout.ld");
    }

    // Chip-specific `device.x` files are owned by the active PAC's `rt` feature
    // (ws63-pac/rt or bs2x-pac/rt). This crate's entry script still INCLUDEs
    // `device.x`, but it deliberately does not copy one into its own OUT_DIR.
    if stale_device_out.exists() {
        fs::remove_file(&stale_device_out).expect("Failed to remove stale runtime-owned device.x");
    }
    fs::copy(symbols_x, &symbols_out).expect("Failed to copy riscv-rt-symbols.x");

    if boot_header_enabled {
        fs::copy(ws63_boot_header_x, &boot_header_out).expect("Failed to copy boot-header.x");
    } else if boot_header_out.exists() {
        fs::remove_file(&boot_header_out).expect("Failed to remove stale boot-header.x");
    }

    // Downstream binaries use the single neutral entry script name:
    // `-Thisi-riscv-link.x`.
    let link_out = out_dir.join("hisi-riscv-link.x");
    let mut link_contents = String::from("/* Auto-generated by hisi-riscv-rt/build.rs. */\n");
    if chip_ws63 && bundled_memory && ws63_bgle_32k {
        // The 32 KiB BGLE bank reduces the ACPU packet-RAM window from
        // 576 KiB to 544 KiB. Keep the linker boundary in lockstep with the
        // RAM9 ownership programmed by __hisi_ws63_shared_ram_init().
        link_contents.push_str(
            "__hisi_ws63_app_sram_length = \
             DEFINED(__hisi_ws63_app_sram_length) ? \
             __hisi_ws63_app_sram_length : 0x85f00;\n",
        );
    }
    if ws63_radio_main_stack_32k {
        // This assignment must precede INCLUDE memory.x. The bundled WS63
        // memory.x uses DEFINED(__stack_size), so the profile default
        // participates in section layout instead of becoming a too-late
        // post-script --defsym override. Application-owned memory.x files may
        // still set a larger explicit value before including this entry script.
        link_contents.push_str("__stack_size = DEFINED(__stack_size) ? __stack_size : 0x8000;\n");
    }
    link_contents.push_str(
        "INCLUDE memory.x\n\
         INCLUDE layout.ld\n\
         INCLUDE device.x\n\
         INCLUDE riscv-rt-symbols.x\n",
    );
    if boot_header_enabled {
        link_contents.push_str("INCLUDE boot-header.x\n");
    }
    fs::write(&link_out, &link_contents).expect("Failed to write hisi-riscv-link.x");

    // ---- riscv-rt-start-experiment: compile assembly via cc ----
    // Avoids LTO/global_asm! conflicts with riscv-rt's weak __pre_init and
    // _setup_interrupts. The compiled .o is linked directly as a native object,
    // which bypasses the LLVM LTO merge that would otherwise see duplicate symbols.
    if riscv_rt_start_experiment {
        let asm_path = Path::new("asm/ws63/startup_riscvrt.S");
        let obj_path = out_dir.join("startup_riscvrt.o");
        let cc = "riscv64-unknown-elf-gcc";

        let status = std::process::Command::new(cc)
            .args([
                "-x",
                "assembler-with-cpp",
                "-c",
                "-march=rv32imfc",
                "-mabi=ilp32f",
                "-o",
                obj_path.to_str().unwrap(),
                asm_path.to_str().unwrap(),
            ])
            .status()
            .unwrap_or_else(|e| panic!("Failed to run {}: {}", cc, e));

        if !status.success() {
            {
                panic!("{} failed to compile {}", cc, asm_path.display());
            }
        }

        println!("cargo:rustc-link-arg={}", obj_path.display());
        println!("cargo:rerun-if-changed={}", asm_path.display());
    }

    println!("cargo:rustc-link-search={}", out_dir.display());

    println!("cargo:rustc-env=RISCV_RT_BASE_ISA=rv32i");

    if chip_ws63 {
        println!("cargo:rustc-cfg=target_chip=\"ws63\"");
    } else if chip_bs21 {
        println!("cargo:rustc-cfg=target_chip=\"bs2x\"");
    }
}

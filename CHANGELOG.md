# Changelog

All notable changes to ws63-rt will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Runtime support crate for HiSilicon WS63 (RISC-V RV32IMFC_Zicsr)
- Startup assembly (`asm/startup.S`) — reset vector, stack initialization, BSS clear
- Linker scripts:
  - `memory.x` — flash and RAM memory layout
  - `layout.ld` — output section layout
  - `device.x` — interrupt vector table with PROVIDE weak defaults
- Custom RISC-V target specification (`target-specs/riscv32imfc-unknown-none-elf.json`)
- `build.rs` — copies linker scripts to OUT_DIR, sets linker args, configures `riscv-rt`
- Interrupt vector definitions for all WS63 interrupt sources (TIMER, RTC, I2C, GPIO, UART, SPI, DMA, BLE, etc.)
- `entry` macro re-export for application entry point declaration

### Changed

- `ws63-rt` is a workspace member consumed by all `ws63-examples/*` binaries

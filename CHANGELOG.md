# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.2] - 2026-06-15

### Changed

- Bump the `ws63-pac` dependency requirement to `0.2` (was `0.1`) to track the
  ws63-pac 0.2.0 release (SPI_WSR bit-layout + TIMER fixes). No runtime change —
  rt's startup/linker/`device.x` are unaffected by the pac fix; this is purely a
  version-requirement bump so an app can depend on both `hisi-riscv-rt` and
  `hisi-riscv-hal 0.4` (which also needs ws63-pac 0.2) without a resolver conflict.

## [0.2.1] - 2026-06-14

### Added

- Optional `boot-header` cargo feature (default OFF, byte-identical when off).
  Bakes the 0x300-byte HiSilicon app-image header into the ELF at flash
  `0x230000` at link time, with a linker-computed `code_area_len`
  (`__hisi_app_body_len`); the body hash is filled post-link by
  `hisi-fwpkg patch-hash`. Lets `probe-rs download` / `probe-rs run`
  of the bare ELF boot with no separate `hisi-fwpkg image` step — and enables
  on-target `embedded-test`. Validated on real WS63 silicon.

## [0.2.0] - 2026-06-05

### Added

- `bundled-memory-x` feature (default): hisi-riscv-rt ships its bundled `memory.x` +
  linker scripts and exports them via `cargo:rustc-link-search`. Disable the
  feature to let a binary supply its **own** `memory.x` (e.g. the `custom_memory`
  example) without a duplicate-symbol / layout conflict.

## [0.1.1] - 2026-06-02

### Changed

- CI: first release cut by hisi-riscv-rt's own repo pipeline; adds the repo's release.yml (no functional change since 0.1.0).

## [0.1.0] - 2026-06-02

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
- `ARCHITECTURE.md` — comprehensive documentation of runtime design and startup flow
- Vectored interrupt mode (mtvec Vectored) with trap entry table (64-byte aligned)
- Explicit `.trap*` section placement in linker script with KEEP directives
- riscv-rt v0.14 compatible linker symbols (_max_hart_id, _hart_stack_size, _stack_start, __sdata, __edata, __sbss, __ebss, __sidata)
- 20 exception handler symbols (SupervisorSoft through StorePageFault) via startup.S
- REGION_ALIAS for riscv-rt compatibility (REGION_STACK, etc.)
- Wrapper linker script (`ws63-link.x`) for downstream binary linking via rustc-link-search

### Changed

- `hisi-riscv-rt` is a workspace member consumed by all `ws63-examples/*` binaries
- startup.S: changed mtvec to Vectored mode for proper interrupt routing to trap_vector entries
- Startup disables all MIE during init; runtime_init now re-enables MEIE, MTIE, MSIE before main()
- Stack symbols (__irq_stack_top, __exc_stack_top, __nmi_stack_top) now defined authoritatively in .stacks section (layout.ld/memory.x), single source of truth
- Linker script: explicit deterministic placement of .trap and .trap.* sections contiguous and in jump range, with KEEP to prevent garbage collection

### Fixed

- trap: vectored mtvec mode + explicit .trap placement + unified trap stacks — interrupts now route correctly through trap_vector entries (was silently falling through to exception handler)
- build: export linker scripts to downstream binaries via rustc-link-search + ws63-link.x wrapper (cargo:rustc-link-arg from lib deps does not propagate to binaries)
- MIE IRQ macro typo (was MIU)
- Inline asm comment alignment in startup.rs
- Rust 2024 edition compatibility: unsafe extern blocks and #[no_mangle]
- Cargo.toml: removed stale defmt feature, use path dependency for ws63-pac
- LLVM assembler compatibility: replaced fssr with csrwi fflags
- P1-S3/S4: re-enable machine interrupts (MEIE, MTIE, MSIE) before main() entry
- CI: build with ws63 toolchain + sibling ws63-pac (was using stable with unavailable riscv32imfc target)

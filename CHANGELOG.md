# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Release/CI now resolve PAC dependencies from crates.io under `--locked`; local
  monorepo development continues to use the parent workspace's `[patch.crates-io]`
  for local PAC checkouts.
- WS63 interrupt symbols now come from `ws63-pac/rt`, matching the BS2X
  `bs2x-pac/rt` ownership model. `hisi-riscv-rt` still `INCLUDE`s `device.x`
  from the linker entry script, but no longer carries its own WS63 copy.
- BS2X runtime support is now explicitly `unstable` and owns a BS21/BS2X default
  `memory.x` plus `linker/bs2x/layout.ld`; BS20/custom boards can still disable
  `bundled-memory-x` and provide their own memory map.

## [0.4.0]

### Changed

- **DIRECT-mode interrupt routing** (BREAKING): `mtvec` is now set to DIRECT mode
  (was vectored). All traps reach `trap_entry`, which branches on `mcause` bit 31 —
  exceptions keep the existing `excp_vect_table` path (unchanged); interrupts compute
  the IRQ number and call `__rt_irq_dispatch`, whose default indexes a new
  `__INTERRUPTS` table (`.rodata`, IRQ 0..72, built from `ws63_pac::interrupt::
  ExternalInterrupt`, gaps → `DefaultHandler`) and tail-calls the **`device.x`-named
  handler** for that IRQ. So an app defines `#[no_mangle] extern "C" fn TIMER_INT0()`
  / `GPIO_INT0()` / … (overriding the weak `device.x` PROVIDE) and the rt routes the
  fired interrupt there — **no per-app `mcause` test / custom `mtvec` needed**.
  `__rt_irq_dispatch` stays weak, so an app may still replace the whole dispatcher
  with a single hook. Why this was needed: the WS63 (Nuclei ECLIC) only delivers a
  custom interrupt once its `LOCIPRI` priority exceeds the threshold (set by
  `hisi-riscv-hal`'s `interrupt::init`/`enable`), and the old vectored entries
  (`mie0..5` / `local_interrupt_handler`) never fired on silicon. The old vectored
  table entries 1-91 are now dead but harmless. **Silicon-verified on real WS63**
  (HIL `timer_int0_named_routing` + `gpio_int0_named_routing`; full driver suite 20/20).

## [0.3.0]

### Changed

- **No default chip** (BREAKING, esp-hal style — mirrors hisi-riscv-hal 0.5.0):
  `default` drops `chip-ws63` → `default = ["bundled-memory-x"]`. The runtime
  (startup asm, reset vector, linker scripts, critical-section impl) is chip-neutral
  and compiles without a chip; only the PAC `interrupt` re-export needs one. Every
  consumer now selects its chip explicitly (`features = ["chip-ws63"]` /
  `["chip-bs21"]`) or gets it transitively from `hisi-riscv-hal`'s chip forwarding
  (`hal/chip-ws63 → hisi-riscv-rt/chip-ws63`). `bundled-memory-x` stays default, so
  the bundled WS63 `memory.x`/`device.x` are unchanged. Workspace `cargo build` /
  `cargo check --workspace` still pass via feature unification from the ws63 examples.

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

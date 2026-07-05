# hisi-riscv-rt

Bare-metal runtime entry support for HiSilicon RISC-V firmware.

This crate keeps the user-facing runtime interface small and stable:

- re-exports `riscv-rt` entry attributes (`entry`, `pre_init`);
- re-exports the selected PAC interrupt enum;
- registers the single-hart critical-section implementation through the `riscv`
  crate;
- selects chip startup/linker adapters behind Cargo features.

## Adapters

- `chip-ws63`: WS63 reset/trap startup, linker layout, `ws63-pac/rt` interrupt
  symbols, and the optional link-time `boot-header` image header.
- `chip-bs21` + `unstable`: BS2X compatibility path. This crate provides a
  BS21/BS2X default `memory.x`, BS2X linker layout, legacy startup, and
  `bs2x-pac/rt` provides BS2X `device.x`. BS20/custom boards can override the
  default by disabling `bundled-memory-x` and providing their own `memory.x`.

Hi3322 is intentionally not exposed as a startup feature yet. The vendor platform
uses TES/TEE CSRs (`tmtvec`, `tmstatus`, `tmedeleg`, `tmesvec`), CLIC setup, and a
different memory/image model, so it needs a dedicated adapter after PAC/linker/board
evidence exists.

## Usage

```rust
#![no_std]
#![no_main]

use hisi_riscv_rt::entry;

#[entry]
fn main() -> ! {
    loop {}
}
```

Downstream binaries should link with:

```text
-Thisi-riscv-link.x
```

`ws63-link.x` is still generated as a temporary compatibility alias for older
applications, but new code should use the neutral name.

## Stability

Stable runtime surface:

- `entry` / `pre_init` facade over `riscv-rt`;
- `chip-ws63` default startup/linker path;
- WS63 `boot-header` when `chip-ws63` is enabled.

Unstable runtime surface:

- `chip-bs21` BS2X compatibility adapter;
- `riscv-rt-start-experiment`.

## Bundled Memory Layouts

`bundled-memory-x` emits the active chip's default `memory.x`: WS63 for
`chip-ws63`, or BS21/BS2X 160K L2RAM for `chip-bs21`. BS20 has 128K L2RAM and
should provide its own `memory.x`.

### WS63

| Region | Base | Size | Description |
| --- | --- | --- | --- |
| BOOTROM | 0x100000 | 36K | Mask ROM boot code |
| ROM | 0x109000 | 268K | Application ROM support code |
| ITCM | 0x14C000 | 16K default | Instruction TCM |
| DTCM | 0x180000 | 16K default | Data TCM |
| FLASH | 0x200000 | 8MB | External SPI NOR flash |
| PROGRAM | 0x230300 | ~2.25MB | Application code after WS63 boot header |
| SRAM | 0xA00000 | 576K default | Main system RAM |

### BS21 / BS2X Default

| Region | Base | Size | Description |
| --- | --- | --- | --- |
| BOOTROM | 0x00000000 | 32K | Mask ROM window |
| ROM | 0x00008000 | 480K | Remaining ROM window |
| ITCM | 0x00080000 | 448K | Instruction TCM before DTCM carve-out |
| DTCM | 0x000F0000 | 64K | Data TCM carve-out |
| FLASH | 0x10000000 | 1MB | XIP NOR flash |
| PROGRAM | 0x10000000 | 1MB | Application code |
| SRAM | 0x00100000 | 160K | BS21/BS2X L2RAM default |

## License

MIT

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
- `chip-bs21`: BS2X compatibility path. BS20/BS21 examples provide their own
  `memory.x`; this crate provides the shared legacy startup/layout; `bs2x-pac/rt`
  provides BS2X `device.x`.

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

## WS63 Memory Layout

The bundled `memory.x` is WS63-only and emitted only when both `bundled-memory-x`
and `chip-ws63` are selected. BS2X binaries supply their own `memory.x`.

| Region | Base | Size | Description |
| --- | --- | --- | --- |
| BOOTROM | 0x100000 | 36K | Mask ROM boot code |
| ROM | 0x109000 | 268K | Application ROM support code |
| ITCM | 0x14C000 | 16K default | Instruction TCM |
| DTCM | 0x180000 | 16K default | Data TCM |
| FLASH | 0x200000 | 8MB | External SPI NOR flash |
| PROGRAM | 0x230300 | ~2.25MB | Application code after WS63 boot header |
| SRAM | 0xA00000 | 576K default | Main system RAM |

## License

MIT

# ws63-rt — Runtime for HiSilicon WS63 (RISC-V RV32IMFC)

Bare-metal runtime support for the HiSilicon WS63 chip (Q353333N1100 series),
a 2.4GHz Wi-Fi 6 + BLE 5.4 + SLE combo SoC.

## Features

- **Assembly startup**: Reset vector, trap vector, interrupt dispatch, stack initialization
- **Rust runtime**: BSS zeroing, data section copy from flash to RAM, cache enable
- **Exception handlers**: Full RISC-V exception dispatch (misaligned, fault, illegal, ecall, page fault, etc.)
- **Interrupt controller**: Custom WS63 vectored interrupt mode with 6 MIE + 60 local IRQ handlers
- **Linker script**: Memory layout for ITCM, DTCM, SRAM, and SPI flash
- **FPU support**: Single-precision hardware float (RV32F)
- **Custom target**: `riscv32imfc-unknown-none-elf.json`

## Usage

```rust
#![no_std]
#![no_main]

use ws63_rt::entry;

#[entry]
fn main() -> ! {
    loop {
        // Your embedded application here
    }
}

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {}
}
```

## Memory Layout

| Region | Base | Size | Description |
|--------|------|------|-------------|
| BOOTROM | 0x100000 | 36K | Mask ROM boot code |
| ROM | 0x109000 | 268K | Application ROM (peripheral boot code) |
| ITCM | 0x14C000 | 16K | Instruction TCM (fast code) |
| DTCM | 0x180000 | 16K | Data TCM (fast data) |
| FLASH | 0x200000 | 8MB | External SPI NOR flash |
| PROGRAM | 0x230300 | ~3MB | Application binary in flash |
| SRAM | 0xA00000 | 576K | Main system RAM |

## Building

```bash
# Build with the custom target
cargo build --target target-specs/riscv32imfc-unknown-none-elf.json

# Or set up .cargo/config.toml:
#
# [build]
# target = "target-specs/riscv32imfc-unknown-none-elf.json"
#
# [target.'cfg(target_arch = "riscv32")']
# runner = "gdb-multiarch"
```

## License

MIT

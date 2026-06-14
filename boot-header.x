/*
 * WS63 link-time boot header placement (hisi-riscv-rt `boot-header` feature).
 *
 * Places the 0x300-byte `.boot_header` section (the Rust `BOOT_HEADER` static in
 * src/boot_header.rs) at flash 0x230000 — i.e. at `app_partition` — so it ends
 * exactly where `.startup` begins at ORIGIN(PROGRAM) = 0x230300. The bare ELF is
 * then a directly bootable WS63 image: 0x300 header @ 0x230000 + app body @
 * 0x230300, with no separate `hisi-fwpkg image` packaging step.
 *
 * This is INCLUDEd by ws63-link.x BEFORE layout.ld only when the `boot-header`
 * feature is enabled (build.rs gates it on CARGO_FEATURE_BOOT_HEADER). The
 * default (feature-off) link never sees this file, so the layout is unchanged.
 *
 * The section is placed at the absolute address 0x230000 and assigned to the
 * FLASH MEMORY region (0x200000..0xA00000, from memory.x, which is INCLUDEd
 * after this file but is in scope by link time): 0x230000 lies inside FLASH, and
 * nothing else is placed directly in FLASH (layout.ld only uses FLASH/PROGRAM as
 * AT> LMA targets), so the header is the first and only direct FLASH content. lld
 * merges this SECTIONS block with layout.ld's. No ALIGN is applied: the header
 * must start exactly at 0x230000, ending at 0x230300 = ORIGIN(PROGRAM).
 */
SECTIONS
{
    .boot_header 0x230000 : AT(0x230000)
    {
        KEEP(*(.boot_header))
    } > FLASH

    /* When a SECTIONS block places an absolute-addressed allocated section like
     * .boot_header, lld's orphan-placement heuristic can wedge the orphan
     * .eh_frame (emitted by rustc for unwind tables) right after it — overlapping
     * .startup at 0x230300. Explicitly place .eh_frame into the PROGRAM region (its
     * normal home: in the feature-off build it lands just after .text) so it is no
     * longer an orphan and lld leaves it where it belongs. This block is only ever
     * linked in the boot-header build, so the default layout is unchanged. */
    .eh_frame : ALIGN(4) {
        KEEP(*(.eh_frame .eh_frame.*))
    } > PROGRAM
}
ASSERT(SIZEOF(.boot_header) == 0x300,
       "boot_header: .boot_header section must be exactly 0x300 bytes");

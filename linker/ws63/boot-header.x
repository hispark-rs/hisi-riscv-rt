/*
 * WS63 link-time boot header placement (hisi-riscv-rt `boot-header` feature).
 *
 * Places the 0x300-byte `.boot_header` section at flash 0x230000 — i.e. at
 * `app_partition` — so it ends exactly where `.startup` begins at
 * ORIGIN(PROGRAM) = 0x230300. The bare ELF is then a directly bootable WS63
 * image: 0x300 header @ 0x230000 + app body @ 0x230300, with no separate
 * `hisi-fwpkg image` packaging step.
 *
 * "Route 2": the header content is mostly constant (the Rust BOOT_HEADER_PART0/
 * 1/2 statics in src/boot_header.rs), but the two body-dependent length fields
 * `code_area_len` (@0x230124) and `code_uncompress_len` (@0x230180) are emitted
 * HERE by the linker as `__hisi_app_body_len` — the real body length, computed
 * as `__hisi_body_end - 0x00230300`. A Rust `static` initializer cannot
 * const-read a relocation, so the header body is split into three byte arrays
 * and stitched back together below with the two LONG() words interleaved at the
 * right offsets:
 *
 *   part0 = [0x000..0x124] (0x124 bytes)
 *   LONG(__hisi_app_body_len)              @ 0x124  (code_area_len)
 *   part1 = [0x128..0x180] (0x058 bytes)   (code_area_hash @0x128 = 0, patched post-link)
 *   LONG(__hisi_app_body_len)              @ 0x180  (code_uncompress_len)
 *   part2 = [0x184..0x300] (0x17C bytes)
 *   => 0x124 + 4 + 0x58 + 4 + 0x17C = 0x300.
 *
 * `code_area_hash` (@0x230128, 32 bytes) stays zero here — flashboot checks the
 * body hash even with secure-verify disabled, so it MUST be the real SHA-256 of
 * the body, which the linker cannot compute. `hisi-fwpkg patch-hash <elf>`
 * fills it post-link.
 *
 * This is INCLUDEd by hisi-riscv-link.x only when the `boot-header` feature is
 * enabled (build.rs gates it on CARGO_FEATURE_BOOT_HEADER). The old ws63-link.x
 * name remains a temporary compatibility alias. The default (feature-off) link
 * never sees this file, so the layout is unchanged.
 */
SECTIONS
{
    .boot_header 0x230000 : AT(0x230000)
    {
        KEEP(*(.boot_header.part0));     /* [0x000..0x124] */
        LONG(__hisi_app_body_len);       /* code_area_len      @ 0x124 */
        KEEP(*(.boot_header.part1));     /* [0x128..0x180], hash @0x128 = 0 */
        LONG(__hisi_app_body_len);       /* code_uncompress_len @ 0x180 */
        KEEP(*(.boot_header.part2));     /* [0x184..0x300] */
    } > FLASH

    /* Discard .eh_frame (rustc unwind tables). On bare-metal `#![no_std]` with a
     * `#[panic_handler]` that just loops, unwind tables are dead weight — they are
     * never used. Keeping them would place .eh_frame in the boot-header PT_LOAD
     * segment, inflating code_area_len beyond the actual executable body and
     * breaking hisi-fwpkg patch-hash validation. Discarding is safe here. */
    /DISCARD/ : { *(.eh_frame .eh_frame.*) }

    /* Body-end marker: the end address of the last flash-resident (PROGRAM /
     * REGION_TEXT / REGION_RODATA) content. With .eh_frame discarded, the last
     * section in PROGRAM is .text (or .init.trap); this marker follows it so
     * `__hisi_body_end` == end-of-body VMA. `code_area_len`/`code_uncompress_len`
     * above are then `__hisi_body_end - 0x230300` = the real body length.
     * (Forward references in absolute-symbol expressions resolve in lld's final
     * pass, so using __hisi_body_end above before it is defined here is fine.) */
    .hisi_body_end_marker (ALIGN(1)) : {
        __hisi_body_end = .;
    } > PROGRAM
}
__hisi_app_body_len = __hisi_body_end - 0x00230300;
ASSERT(SIZEOF(.boot_header) == 0x300,
       "boot_header: .boot_header section must be exactly 0x300 bytes");

//! WS63 link-time boot header (`boot-header` feature).
//!
//! flashboot loads the WS63 application image from flash `0x230000` and jumps
//! **unconditionally** to `0x230300` (= `app_partition + 0x300`). A bootable
//! image is therefore a fixed `0x300`-byte HiSilicon header at `0x230000`
//! immediately followed by the app code at `0x230300`.
//!
//! Normally that header is added *post-build* by `hisi-fwpkg image`. With the
//! `boot-header` feature enabled, this module bakes a structurally-correct
//! header **into the ELF at link time** (section `.boot_header`, placed by the
//! linker at flash `0x230000`), so `probe-rs download <elf>` / `cargo flash`
//! write a directly bootable image with no separate packaging step.
//!
//! ## "Route 2": link-time length, post-link hash
//!
//! On-silicon measurement shows flashboot checks the **body hash** even with
//! secure-verify disabled (zeroing only `code_area_hash` of a known-good image
//! stops it booting). So `code_area_hash` MUST be the real SHA-256 of the body
//! and `code_area_len` the real body length (the hash is computed over the
//! first `code_area_len` body bytes). A linker cannot compute SHA-256, so the
//! hash is a **post-link** patch (`hisi-fwpkg patch-hash`). The length, however,
//! *can* be a linker symbol — so this module bakes everything except the two
//! body-dependent fields at link time:
//!
//! * `code_area_len` (code-info `+0x24` = `0x124`) and `code_uncompress_len`
//!   (code-info `+0x80` = `0x180`) are emitted by the **linker** as
//!   `__hisi_app_body_len` (`__hisi_body_end - 0x230300`), via `LONG(...)`
//!   directives in `boot-header.x` — a Rust `static` initializer cannot
//!   const-read a relocation. To make room for those linker words, the header
//!   body is split here into three byte-array statics (`part0`/`part1`/`part2`)
//!   placed in sections `.boot_header.part0/1/2`; `boot-header.x` stitches them
//!   back together with the two `LONG` words interleaved at the right offsets.
//! * `code_area_hash` (code-info `+0x28` = `0x128`, 32 bytes): left **zero** in
//!   `part1` — patched post-link by `hisi-fwpkg patch-hash`.
//! * `text_segment_size` (code-info `+0x84`): left **zero** (informational
//!   only; the vendor default `0x10000` is not needed to boot).
//!
//! The three parts and the two interleaved `LONG` words reassemble to the exact
//! same `0x300`-byte layout produced field-for-field by `hisi-fwpkg`'s
//! `build_image_header` (`hisi-fwpkg/crates/hisi-fwpkg/src/image.rs`).

/// `APPBOOT_KEY_AREA_IMAGE_ID` — magic of the key area (offset 0x000).
const APP_KEY_AREA_IMAGE_ID: u32 = 0x4B0F_2D1E;
/// `APPBOOT_CODE_INFO_IMAGE_ID` — magic of the code-info area (offset 0x100).
const APP_CODE_INFO_IMAGE_ID: u32 = 0x4B0F_2D2D;

/// Length of the key area, `KEY_AREA_STRUCTURE_LENGTH` (ECC/SM2 build).
const KEY_AREA_LEN: usize = 0x100;
/// Length of the code-info area, `CODE_INFO_STRUCTURE_LENGTH` (ECC/SM2 build).
const CODE_INFO_LEN: usize = 0x200;
/// Total fixed image header length, `APP_IMAGE_HEADER_LEN`.
const IMAGE_HEADER_LEN: usize = KEY_AREA_LEN + CODE_INFO_LEN; // 0x300

/// `structure_version`, vendor uses `0x00010000`.
const STRUCTURE_VERSION: u32 = 0x0001_0000;
/// ECC-bp256 signature length in bytes (`BOOT_SIG_LEN`).
const SIG_LEN: u32 = 0x40;
/// `KeyAlg` for ECC256 / brainpoolP256r1 (`0x2A13C812`).
const KEY_ALG_ECC256: u32 = 0x2A13_C812;
/// `ecc_curve_type` for brainpoolP256r1 (`0x2A13C812`).
const ECC_CURVE_BP256R1: u32 = 0x2A13_C812;
/// ECC-bp256 public key length in bytes (`BOOT_PUBLIC_KEY_LEN`).
const PUB_KEY_LEN: u32 = 0x40;
/// `FLASH_NO_ENCRY_FLAG` — `code_enc_flag` value meaning "**not** encrypted".
///
/// Counterintuitively non-zero: flashboot's `ws63_flash_encrypt_config()` does
/// `if (code_enc_flag == FLASH_NO_ENCRY_FLAG) return;`, so a zero value would
/// make it try to configure on-the-fly flash decryption and fail to boot a
/// plaintext image.
const FLASH_NO_ENCRY_FLAG: u32 = 0x3C78_96E1;

// ---- ImageOptions defaults (matching hisi-fwpkg's ImageOptions::default) ----
const KEY_OWNER_ID: u32 = 1;
const KEY_ID: u32 = 1;
const KEY_VERSION_EXT: u32 = 0;
const KEY_VERSION_MASK: u32 = 0;
const VERSION_EXT: u32 = 0;
const VERSION_MASK: u32 = 0;
const MSID: u32 = 0;
const MSID_MASK: u32 = 0;
/// `text_segment_size` — informational only; not needed to boot.
const TEXT_SEGMENT_SIZE: u32 = 0;

/// Write a little-endian `u32` into `buf` at byte offset `off` (const-fn).
const fn put_u32(mut buf: [u8; IMAGE_HEADER_LEN], off: usize, v: u32) -> [u8; IMAGE_HEADER_LEN] {
    let b = v.to_le_bytes();
    buf[off] = b[0];
    buf[off + 1] = b[1];
    buf[off + 2] = b[2];
    buf[off + 3] = b[3];
    buf
}

/// Build the full `0x300`-byte WS63 app image header, with the body-dependent
/// length fields (`code_area_len` @0x124, `code_uncompress_len` @0x180) and the
/// `code_area_hash` (@0x128) left **zero**. The two lengths are overwritten by
/// the linker (see `boot-header.x`); the hash is patched post-link. Mirrors
/// `hisi-fwpkg::image::build_image_header` field-for-field. Used only to slice
/// out the three constant parts below.
const fn build_header() -> [u8; IMAGE_HEADER_LEN] {
    let mut h = [0u8; IMAGE_HEADER_LEN];

    // ---- Key area (image_key_area_t), offset 0x000, length 0x100 ----
    h = put_u32(h, 0x00, APP_KEY_AREA_IMAGE_ID); // image_id
    h = put_u32(h, 0x04, STRUCTURE_VERSION); // structure_version
    h = put_u32(h, 0x08, KEY_AREA_LEN as u32); // structure_length (0x100)
    h = put_u32(h, 0x0C, SIG_LEN); // signature_length (0x40)
    h = put_u32(h, 0x10, KEY_OWNER_ID); // key_owner_id
    h = put_u32(h, 0x14, KEY_ID); // key_id
    h = put_u32(h, 0x18, KEY_ALG_ECC256); // key_alg
    h = put_u32(h, 0x1C, ECC_CURVE_BP256R1); // ecc_curve_type
    h = put_u32(h, 0x20, PUB_KEY_LEN); // key_length (0x40)
    h = put_u32(h, 0x24, KEY_VERSION_EXT); // key_version_ext
    h = put_u32(h, 0x28, KEY_VERSION_MASK); // mask_key_version_ext
    h = put_u32(h, 0x2C, MSID); // msid_ext
    h = put_u32(h, 0x30, MSID_MASK); // mask_msid_ext
    h = put_u32(h, 0x34, 0); // maintenance_mode (disabled)
    h = put_u32(h, 0x48, 0); // code_info_addr (0 = immediately follows)
    // die_id[16] @ 0x38, ext_public_key_area + sig_key_area — dummy zero

    // ---- Code-info area (image_code_info_t), offset 0x100, length 0x200 ----
    const CI: usize = KEY_AREA_LEN;
    h = put_u32(h, CI + 0x00, APP_CODE_INFO_IMAGE_ID); // image_id
    h = put_u32(h, CI + 0x04, STRUCTURE_VERSION); // structure_version
    h = put_u32(h, CI + 0x08, CODE_INFO_LEN as u32); // structure_length (0x200)
    h = put_u32(h, CI + 0x0C, SIG_LEN); // signature_length (0x40)
    h = put_u32(h, CI + 0x10, VERSION_EXT); // version_ext
    h = put_u32(h, CI + 0x14, VERSION_MASK); // mask_version_ext
    h = put_u32(h, CI + 0x18, MSID); // msid_ext
    h = put_u32(h, CI + 0x1C, MSID_MASK); // mask_msid_ext
    h = put_u32(h, CI + 0x20, 0); // code_area_addr (0 = immediately follows)
    // code_area_len @ CI+0x24 (=0x124) — left zero, emitted by the linker
    // code_area_hash[32] @ CI+0x28 (=0x128) — left zero, patched post-link
    h = put_u32(h, CI + 0x48, FLASH_NO_ENCRY_FLAG); // code_enc_flag
    // protection_key_l1/l2 + iv @ CI+0x4C.. — zero (encryption disabled)
    h = put_u32(h, CI + 0x7C, 0); // code_compress_flag (0 = not compressed)
    // code_uncompress_len @ CI+0x80 (=0x180) — left zero, emitted by the linker
    h = put_u32(h, CI + 0x84, TEXT_SEGMENT_SIZE); // text_segment_size
    // sig_code_info + ext — dummy zero

    h
}

/// The full header laid out once at compile time; the three `BOOT_HEADER_PARTN`
/// statics below are constant slices of it. The two length words at `0x124` and
/// `0x180` are *holes* (zero here) filled by the linker; `0x128..0x148` (hash)
/// is also zero, filled post-link.
const HEADER: [u8; IMAGE_HEADER_LEN] = build_header();

/// Linker-word offsets that split the header. `code_area_len` lives at
/// `0x124`, `code_uncompress_len` at `0x180`; each is a 4-byte hole the linker
/// fills, so the constant parts are the spans *around* them.
const LEN_OFF: usize = 0x124; // code_area_len
const UNCOMPLEN_OFF: usize = 0x180; // code_uncompress_len

/// `[0x000 .. 0x124]` — everything up to (not including) `code_area_len`.
const PART0_LEN: usize = LEN_OFF; // 0x124
/// `[0x128 .. 0x180]` — between `code_area_len` and `code_uncompress_len`
/// (includes the zero `code_area_hash` @0x128).
const PART1_LEN: usize = UNCOMPLEN_OFF - (LEN_OFF + 4); // 0x58
/// `[0x184 .. 0x300]` — everything after `code_uncompress_len`.
const PART2_LEN: usize = IMAGE_HEADER_LEN - (UNCOMPLEN_OFF + 4); // 0x17C

// The three parts plus the two 4-byte linker words must reconstruct 0x300.
const _: () = assert!(PART0_LEN + 4 + PART1_LEN + 4 + PART2_LEN == IMAGE_HEADER_LEN);

/// Copy a constant `N`-byte slice of `HEADER` starting at `start` (const-fn;
/// `<[u8]>::try_into`/slicing isn't const-stable for arrays here).
const fn slice<const N: usize>(start: usize) -> [u8; N] {
    let mut out = [0u8; N];
    let mut i = 0;
    while i < N {
        out[i] = HEADER[start + i];
        i += 1;
    }
    out
}

/// `.boot_header` part 0: header bytes `[0x000 .. 0x124]`. Immediately followed
/// in the linked output by the linker word `code_area_len` (see `boot-header.x`).
#[used]
#[unsafe(no_mangle)]
#[unsafe(link_section = ".boot_header.part0")]
pub static BOOT_HEADER_PART0: [u8; PART0_LEN] = slice::<PART0_LEN>(0);

/// `.boot_header` part 1: header bytes `[0x128 .. 0x180]` (the zero
/// `code_area_hash` lives here, patched post-link). Sits between the two linker
/// length words.
#[used]
#[unsafe(no_mangle)]
#[unsafe(link_section = ".boot_header.part1")]
pub static BOOT_HEADER_PART1: [u8; PART1_LEN] = slice::<PART1_LEN>(LEN_OFF + 4);

/// `.boot_header` part 2: header bytes `[0x184 .. 0x300]` — after the linker
/// word `code_uncompress_len`.
#[used]
#[unsafe(no_mangle)]
#[unsafe(link_section = ".boot_header.part2")]
pub static BOOT_HEADER_PART2: [u8; PART2_LEN] = slice::<PART2_LEN>(UNCOMPLEN_OFF + 4);

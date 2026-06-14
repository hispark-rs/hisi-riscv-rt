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
//! On a dev chip with secure boot **disabled** (efuse `SEC_VERIFY_ENABLE == 0`),
//! flashboot's `verify_image_*` path short-circuits to success *before* reading
//! any signature or even the body hash, then jumps unconditionally. A static
//! header (magics + structural fields + the non-encrypted `code_enc_flag`, with
//! zero signature/pubkey and zero hash) is therefore sufficient to boot.
//!
//! Field values reproduce `hisi-fwpkg`'s `build_image_header`
//! (`hisi-fwpkg/crates/hisi-fwpkg/src/image.rs`) field-for-field, with the only
//! deltas being the **body-dependent** fields, which flashboot's skipped verify
//! path never reads:
//!
//! * `code_area_len` / `code_uncompress_len` (code-info `+0x24` / `+0x80`):
//!   left **zero**. The real body length is not available as a constant at
//!   compile time, and these are only consumed by the verify path flashboot
//!   skips. (A linker symbol *could* fill them, but a `static` initializer
//!   cannot const-read a relocation, so a post-link patch would be required —
//!   not worth it for a field that is never checked. See module note below.)
//! * `code_area_hash` (code-info `+0x28`, 32 bytes): left **zero** — a real
//!   SHA-256 cannot be computed at link time, and it is only read by the
//!   skipped verify path.
//! * `text_segment_size` (code-info `+0x84`): left **zero** (informational
//!   only; the vendor default `0x10000` is not needed to boot).

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
/// `code_area_len` / `code_uncompress_len`. Zero: body-dependent, never read by
/// flashboot's (skipped) verify path. See module docs.
const CODE_AREA_LEN: u32 = 0;
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

/// Build the `0x300`-byte WS63 app image header. Signature / pubkey / hash blobs
/// and the body-dependent length fields are left zero. Mirrors
/// `hisi-fwpkg::image::build_image_header`.
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
    h = put_u32(h, CI + 0x24, CODE_AREA_LEN); // code_area_len
    // code_area_hash[32] @ CI+0x28 — left zero (verify path skipped)
    h = put_u32(h, CI + 0x48, FLASH_NO_ENCRY_FLAG); // code_enc_flag
    // protection_key_l1/l2 + iv @ CI+0x4C.. — zero (encryption disabled)
    h = put_u32(h, CI + 0x7C, 0); // code_compress_flag (0 = not compressed)
    h = put_u32(h, CI + 0x80, CODE_AREA_LEN); // code_uncompress_len (== code_area_len)
    h = put_u32(h, CI + 0x84, TEXT_SEGMENT_SIZE); // text_segment_size
    // sig_code_info + ext — dummy zero

    h
}

/// The link-time boot header, emitted into section `.boot_header` (placed by the
/// boot-header linker fragment at flash `0x230000`). `#[used]` so it survives
/// `--gc-sections`; `#[no_mangle]` so the linker fragment's `KEEP(*(...))` and
/// any external tooling can find it by name.
#[used]
#[unsafe(no_mangle)]
#[unsafe(link_section = ".boot_header")]
pub static BOOT_HEADER: [u8; IMAGE_HEADER_LEN] = build_header();

/*
 * BS2X boot-header placeholder.
 *
 * The current BS2X route is built and linked as a compatibility runtime target,
 * but this repository does not yet have a verified BS2X image-header/link-time
 * packaging format. Keep this file as the adapter-owned placeholder so the file
 * layout mirrors WS63 without making a bootability claim.
 *
 * build.rs does not INCLUDE this file today. When BS2X packaging is documented
 * and HIL/QEMU evidence exists, replace this comment-only linker fragment with
 * the real SECTIONS placement and gate it behind a chip-specific feature.
 */

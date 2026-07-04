//! Hi3322 adapter placeholder.
//!
//! Hi3322 is not a supported startup adapter yet. The vendor SELiteOS path uses
//! TES/TEE-specific CSRs such as `tmtvec`, `tmstatus`, `tmedeleg`, and `tmesvec`,
//! plus CLIC configuration and a different memory partitioning model. Do not map
//! it onto the WS63 reset path by feature flag; add a dedicated adapter once the
//! PAC, linker map, image packaging, and board validation exist.

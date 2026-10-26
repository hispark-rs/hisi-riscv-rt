//! Experimental application-hart instruction-cache configuration.
//!
//! Source: WS53 SDK 163d9150, arch/cache.h and ws53_liteos_app/libriscv.a
//! cache.c.obj. This is the instruction part of the SDK sequence, not generic
//! boot initialization. It changes no data-cache, PMP or memory attributes.
//! A fence/readback is not proof of DMA drain or completed cache maintenance.
//! No DMA/coherent buffer capability is returned. Default startup never calls it.

/// Sizes accepted by the actual WS53 SDK application library. The header's
/// additional 64 KiB variant is rejected by that library and is not offered here.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum InstructionSize {
    KiB4 = 0,
    KiB8 = 2,
    KiB16 = 4,
    KiB32 = 6,
}
impl InstructionSize {
    pub const fn from_kib(kib: u32) -> Option<Self> {
        match kib {
            4 => Some(Self::KiB4),
            8 => Some(Self::KiB8),
            16 => Some(Self::KiB16),
            32 => Some(Self::KiB32),
            _ => None,
        }
    }
}

/// Explicit instruction-cache size and 1..8 prefetch lines. Construction has
/// no CSR access; invalid line counts cannot reach the configuration sequence.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct InstructionConfig {
    size: InstructionSize,
    lines: u8,
}
impl InstructionConfig {
    pub const fn new(size: InstructionSize, lines: u8) -> Option<Self> {
        if lines == 0 || lines > 8 {
            None
        } else {
            Some(Self { size, lines })
        }
    }
    /// The SDK application profile: 32 KiB instruction cache, four prefetch lines.
    pub const fn sdk_application() -> Self {
        Self {
            size: InstructionSize::KiB32,
            lines: 4,
        }
    }
    pub const fn size(self) -> InstructionSize {
        self.size
    }
    pub const fn prefetch_lines(self) -> u8 {
        self.lines
    }
    const fn control(self) -> u32 {
        self.size as u32 | 1
    }
    const fn prefetch(self) -> u32 {
        ((self.lines as u32 - 1) << 1) | 1
    }
}

/// The phase at which a request was refused. Readback failure may occur after
/// writes have taken effect; there is no automatic rollback or resource release.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum InstructionError {
    InvalidPrefetchLines,
    InterruptsEnabled,
    UnknownControl(u32),
    AlreadyEnabled,
    UnknownPrefetch(u32),
    ControlReadback { expected: u32, observed: u32 },
    PrefetchReadback { expected: u32, observed: u32 },
}

/// Numeric observations only. They do not establish actual cache-line contents,
/// invalidation completion, DMA coherence, memory reachability or timing.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct InstructionObservation {
    pub before_control: u32,
    pub before_prefetch: u32,
    pub after_control: u32,
    pub after_prefetch: u32,
}

trait Registers {
    fn mstatus(&mut self) -> u32;
    fn control(&mut self) -> u32;
    fn prefetch(&mut self) -> u32;
    fn invalidate_all(&mut self);
    fn order_cpu(&mut self);
    fn set_control(&mut self, value: u32);
    fn set_prefetch(&mut self, value: u32);
    fn synchronize_instructions(&mut self);
}
fn configure(io: &mut impl Registers, config: InstructionConfig) -> Result<InstructionObservation, InstructionError> {
    // Refuse invalid internal construction before any CSR access or arithmetic.
    if config.lines == 0 || config.lines > 8 {
        return Err(InstructionError::InvalidPrefetchLines);
    }
    if io.mstatus() & 8 != 0 {
        return Err(InstructionError::InterruptsEnabled);
    }
    let before_control = io.control();
    if before_control & !7 != 0 {
        return Err(InstructionError::UnknownControl(before_control));
    }
    if before_control & 1 != 0 {
        return Err(InstructionError::AlreadyEnabled);
    }
    let before_prefetch = io.prefetch();
    if before_prefetch & !15 != 0 {
        return Err(InstructionError::UnknownPrefetch(before_prefetch));
    }
    // SDK ArchICacheFlush: ICMAINT=4 then fence; ArchICacheEnable writes size|1,
    // ArchICachePrefetchEnable writes (lines-1)<<1|1. No invented busy polling.
    io.invalidate_all();
    io.order_cpu();
    io.set_control(config.control());
    io.set_prefetch(config.prefetch());
    io.synchronize_instructions();
    let after_control = io.control();
    if after_control != config.control() {
        return Err(InstructionError::ControlReadback {
            expected: config.control(),
            observed: after_control,
        });
    }
    let after_prefetch = io.prefetch();
    if after_prefetch != config.prefetch() {
        return Err(InstructionError::PrefetchReadback {
            expected: config.prefetch(),
            observed: after_prefetch,
        });
    }
    Ok(InstructionObservation {
        before_control,
        before_prefetch,
        after_control,
        after_prefetch,
    })
}

/// Issue the SDK-derived instruction-only sequence and check numeric readback.
///
/// # Safety
/// Own this application's hart/cache configuration non-reentrantly; MIE must
/// remain off and no NMI/debugger/other owner may modify it during the call.
/// Run the complete transition closure, literals and exception path from valid,
/// independent RAM; maintain executable mappings and the selected physical
/// cache size. Establish the CPU's instruction-maintenance semantics and any
/// necessary prior quiescence/invalidation-completion protocol externally.
/// All possible instruction writers, including DMA/control-core/Flash updates,
/// must be excluded; establish any required data-to-instruction synchronization.
/// The function does not establish these conditions or configure PMP/clock/RAM.
/// On failure after writes, preserve the execution/mapping contract and recover
/// independently; do not assume the prior control/prefetch state was restored.
///
/// This experimental operation has not yet been enabled on a physical WS53 by
/// this port. A model which returns zero for unknown CSRs cannot qualify it.
#[cfg(target_arch = "riscv32")]
#[inline(never)]
pub unsafe fn configure_instruction_cache(
    config: InstructionConfig,
) -> Result<InstructionObservation, InstructionError> {
    configure(&mut Cpu, config)
}

#[cfg(target_arch = "riscv32")]
struct Cpu;
#[cfg(target_arch = "riscv32")]
impl Registers for Cpu {
    fn mstatus(&mut self) -> u32 {
        let value;
        unsafe {
            core::arch::asm!("csrr {v}, mstatus", v=out(reg)value, options(nostack));
        }
        value
    }
    fn control(&mut self) -> u32 {
        let value;
        unsafe {
            core::arch::asm!("csrr {v}, 0x7c0", v=out(reg)value, options(nostack));
        }
        value
    }
    fn prefetch(&mut self) -> u32 {
        let value;
        unsafe {
            core::arch::asm!("csrr {v}, 0x7c6", v=out(reg)value, options(nostack));
        }
        value
    }
    fn invalidate_all(&mut self) {
        unsafe {
            core::arch::asm!("csrw 0x7c2, {v}", v=in(reg)4u32, options(nostack));
        }
    }
    fn order_cpu(&mut self) {
        unsafe {
            core::arch::asm!("fence iorw, iorw", options(nostack));
        }
    }
    fn set_control(&mut self, value: u32) {
        unsafe {
            core::arch::asm!("csrw 0x7c0, {v}", v=in(reg)value, options(nostack));
        }
    }
    fn set_prefetch(&mut self, value: u32) {
        unsafe {
            core::arch::asm!("csrw 0x7c6, {v}", v=in(reg)value, options(nostack));
        }
    }
    fn synchronize_instructions(&mut self) {
        unsafe {
            core::arch::asm!("fence.i", options(nostack));
        }
    }
}

#[cfg(test)]
mod tests {
    extern crate std;
    use super::*;
    use std::vec::Vec;
    #[derive(Debug, PartialEq, Eq)]
    enum Event {
        Status,
        Control,
        Prefetch,
        Invalidate,
        Fence,
        WriteControl(u32),
        WritePrefetch(u32),
        FenceI,
    }
    struct Io {
        status: u32,
        control: u32,
        prefetch: u32,
        events: Vec<Event>,
        reject_control: bool,
        reject_prefetch: bool,
    }
    impl Io {
        fn new() -> Self {
            Self {
                status: 0,
                control: 6,
                prefetch: 7,
                events: Vec::new(),
                reject_control: false,
                reject_prefetch: false,
            }
        }
    }
    impl Registers for Io {
        fn mstatus(&mut self) -> u32 {
            self.events.push(Event::Status);
            self.status
        }
        fn control(&mut self) -> u32 {
            self.events.push(Event::Control);
            self.control
        }
        fn prefetch(&mut self) -> u32 {
            self.events.push(Event::Prefetch);
            self.prefetch
        }
        fn invalidate_all(&mut self) {
            self.events.push(Event::Invalidate);
        }
        fn order_cpu(&mut self) {
            self.events.push(Event::Fence);
        }
        fn set_control(&mut self, v: u32) {
            self.events.push(Event::WriteControl(v));
            if !self.reject_control {
                self.control = v;
            }
        }
        fn set_prefetch(&mut self, v: u32) {
            self.events.push(Event::WritePrefetch(v));
            if !self.reject_prefetch {
                self.prefetch = v;
            }
        }
        fn synchronize_instructions(&mut self) {
            self.events.push(Event::FenceI);
        }
    }
    #[test]
    fn all_sdk_sizes_and_prefetch_counts_use_exact_sequence() {
        for size in [
            InstructionSize::KiB4,
            InstructionSize::KiB8,
            InstructionSize::KiB16,
            InstructionSize::KiB32,
        ] {
            for lines in 1..=8 {
                let mut io = Io::new();
                let cfg = InstructionConfig::new(size, lines).unwrap();
                let r = configure(&mut io, cfg).unwrap();
                assert_eq!(r.before_control, 6);
                assert_eq!(r.before_prefetch, 7);
                assert_eq!(r.after_control, size as u32 | 1);
                assert_eq!(r.after_prefetch, ((u32::from(lines) - 1) << 1) | 1);
                assert_eq!(
                    io.events,
                    [
                        Event::Status,
                        Event::Control,
                        Event::Prefetch,
                        Event::Invalidate,
                        Event::Fence,
                        Event::WriteControl(cfg.control()),
                        Event::WritePrefetch(cfg.prefetch()),
                        Event::FenceI,
                        Event::Control,
                        Event::Prefetch
                    ]
                );
            }
        }
    }
    #[test]
    fn reject_header_only_64k_and_invalid_line_counts_without_io() {
        for size in [0, 1, 2, 3, 5, 64, 128, u32::MAX] {
            assert!(InstructionSize::from_kib(size).is_none());
        }
        for lines in [0, 9, 10, 127, 255] {
            assert!(InstructionConfig::new(InstructionSize::KiB32, lines).is_none());
            let mut io = Io::new();
            assert_eq!(
                configure(
                    &mut io,
                    InstructionConfig {
                        size: InstructionSize::KiB32,
                        lines
                    }
                ),
                Err(InstructionError::InvalidPrefetchLines)
            );
            assert!(io.events.is_empty());
        }
        for kib in [4, 8, 16, 32] {
            assert!(InstructionSize::from_kib(kib).is_some());
        }
    }
    #[test]
    fn enabled_interrupts_refuse_before_any_cache_csr_access() {
        let mut io = Io::new();
        io.status = 8;
        assert_eq!(
            configure(&mut io, InstructionConfig::sdk_application()),
            Err(InstructionError::InterruptsEnabled)
        );
        assert_eq!(io.events, [Event::Status]);
    }
    #[test]
    fn unknown_control_and_enabled_cache_refuse_without_writes_or_prefetch_reads() {
        for (value, error) in [
            (0x100, InstructionError::UnknownControl(0x100)),
            (0x80000006, InstructionError::UnknownControl(0x80000006)),
            (1, InstructionError::AlreadyEnabled),
            (3, InstructionError::AlreadyEnabled),
            (5, InstructionError::AlreadyEnabled),
            (7, InstructionError::AlreadyEnabled),
        ] {
            let mut io = Io::new();
            io.control = value;
            assert_eq!(configure(&mut io, InstructionConfig::sdk_application()), Err(error));
            assert_eq!(io.events, [Event::Status, Event::Control]);
        }
    }
    #[test]
    fn unknown_prefetch_bits_refuse_without_mutation() {
        for value in [16, 31, 256, u32::MAX] {
            let mut io = Io::new();
            io.prefetch = value;
            assert_eq!(
                configure(&mut io, InstructionConfig::sdk_application()),
                Err(InstructionError::UnknownPrefetch(value))
            );
            assert_eq!(io.events, [Event::Status, Event::Control, Event::Prefetch]);
        }
    }
    #[test]
    fn readback_failure_is_not_rollback_or_maintenance_completion() {
        let mut io = Io::new();
        io.reject_control = true;
        assert_eq!(
            configure(&mut io, InstructionConfig::sdk_application()),
            Err(InstructionError::ControlReadback {
                expected: 7,
                observed: 6
            })
        );
        assert_eq!(io.events.iter().filter(|e| matches!(e, Event::Invalidate)).count(), 1);
        assert_eq!(
            io.events.iter().filter(|e| matches!(e, Event::WriteControl(_))).count(),
            1
        );
        assert_eq!(
            io.events
                .iter()
                .filter(|e| matches!(e, Event::WritePrefetch(_)))
                .count(),
            1
        );
        assert_eq!(io.events.last(), Some(&Event::Control));
    }
    #[test]
    fn prefetch_failure_keeps_observed_effect_of_control_change() {
        let mut io = Io::new();
        io.prefetch = 0;
        io.reject_prefetch = true;
        assert_eq!(
            configure(&mut io, InstructionConfig::sdk_application()),
            Err(InstructionError::PrefetchReadback {
                expected: 7,
                observed: 0
            })
        );
        assert_eq!(io.control, 7);
        assert_eq!(io.events.last(), Some(&Event::Prefetch));
    }
}

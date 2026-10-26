#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyelftools==0.32"]
# ///
"""Offline WS53 I-cache library/compiled-CSR audit; never opens hardware.

The deliberately small interpreter accepts only instructions needed by the
three pinned SDK functions. It reports CSR events, not physical cache effects.
Unknown instructions, external relocations and changed SDK inputs are fatal.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess

from elftools.elf.elffile import ELFFile

COMMIT = "163d9150ab94a02d09a05f623351f9facee3025e"
LIB = "src/kernel/liteos/liteos_v208.5.0/ws53_liteos_app/libriscv.a"
LIB_SHA = "4152f64d9aea2cac0dc7cbf04df10cd1e8d0c6525a5d50ea7efca5ed7c8bf019"
MEMBER_SHA = "809e8fb9e9d832f3f0093bc36ddd01fb2b45d321adfd1cb081f4bca2c6e423d1"
U32 = 0xffffffff


def sha(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def signed(value, width):
    return value - (1 << width) if value & (1 << (width - 1)) else value


def interpret(code, argument):
    """Pure RV32IC subset with private bounded stack and logged CSR writes.

    No host native execution, address mapping, I/O or arbitrary memory access.
    The return sentinel is checked before fetching, and execution is bounded.
    """
    regs, memory, events = [0] * 32, {}, []
    regs[1], regs[2], regs[10] = U32 - 15, 0x1000, argument & U32
    pc = 0

    def stack(address):
        require(0xfe0 <= address <= 0xffc and address % 4 == 0, "stack access out of bounds")
        return address

    for _ in range(64):
        if pc == U32 - 15:
            require(regs[2] == 0x1000 and regs[8] == 0, "SDK did not restore stack/s0")
            return regs[10], events
        require(pc % 2 == 0 and 0 <= pc <= len(code) - 2, "instruction fetch out of bounds")
        half = int.from_bytes(code[pc:pc+2], "little")
        next_pc = pc + (4 if half & 3 == 3 else 2)
        if half & 3 == 3:
            require(pc + 4 <= len(code), "truncated instruction")
            word = int.from_bytes(code[pc:pc+4], "little")
            op, rd, f3, rs1, rs2 = word & 127, (word >> 7) & 31, (word >> 12) & 7, (word >> 15) & 31, (word >> 20) & 31
            if op == 0x13 and f3 in (6, 7):
                imm = signed(word >> 20, 12) & U32
                regs[rd] = regs[rs1] | imm if f3 == 6 else regs[rs1] & imm
            elif op == 0x63 and f3 == 6:
                offset = ((word >> 31) << 12) | (((word >> 7) & 1) << 11) | (((word >> 25) & 63) << 5) | (((word >> 8) & 15) << 1)
                if regs[rs1] < regs[rs2]:
                    next_pc = pc + signed(offset, 13)
            elif op == 0x73 and f3 == 1 and rd == 0:
                require(word >> 20 in (0x7c0, 0x7c2, 0x7c6), "unexpected SDK CSR")
                events.append(["write", word >> 20, regs[rs1]])
            elif word == 0x0ff0000f:
                events.append(["fence", 15, 15])
            else:
                raise ValueError(f"unsupported SDK instruction {word:08x} at {pc:x}")
        else:
            q, f3, rd = half & 3, half >> 13, (half >> 7) & 31
            imm = signed(((half >> 12) & 1) << 5 | ((half >> 2) & 31), 6)
            if q == 1 and f3 == 0:  # C.ADDI
                require(rd != 0, "unexpected hint")
                regs[rd] = (regs[rd] + imm) & U32
            elif q == 1 and f3 == 2:  # C.LI
                require(rd != 0, "unexpected hint")
                regs[rd] = imm & U32
            elif q == 0 and f3 == 0:  # C.ADDI4SPN
                offset = ((half >> 7) & 15) << 6 | ((half >> 11) & 3) << 4 | ((half >> 5) & 1) << 3 | ((half >> 6) & 1) << 2
                require(offset != 0, "reserved C.ADDI4SPN")
                regs[8 + ((half >> 2) & 7)] = (regs[2] + offset) & U32
            elif q == 2 and f3 == 6:  # C.SWSP
                offset = ((half >> 9) & 15) << 2 | ((half >> 7) & 3) << 6
                memory[stack(regs[2] + offset)] = regs[(half >> 2) & 31]
            elif q == 2 and f3 == 2:  # C.LWSP
                offset = ((half >> 12) & 1) << 5 | ((half >> 4) & 7) << 2 | ((half >> 2) & 3) << 6
                address = stack(regs[2] + offset)
                require(rd != 0 and address in memory, "uninitialized stack read")
                regs[rd] = memory[address]
            elif q == 2 and f3 == 4 and not half & 0x1000:
                rs2 = (half >> 2) & 31
                require(rd != 0, "reserved C.JR/MV")
                if rs2:
                    regs[rd] = regs[rs2]
                else:
                    next_pc = regs[rd] & ~1
            elif q == 2 and f3 == 0:  # C.SLLI
                shift = ((half >> 12) & 1) << 5 | ((half >> 2) & 31)
                require(rd != 0 and shift < 32, "reserved RV32 shift")
                regs[rd] = (regs[rd] << shift) & U32
            elif q == 1 and f3 == 7:  # C.BNEZ
                offset = ((half >> 12) & 1) << 8 | ((half >> 10) & 3) << 3 | ((half >> 5) & 3) << 6 | ((half >> 3) & 3) << 1 | ((half >> 2) & 1) << 5
                if regs[8 + ((half >> 7) & 7)]:
                    next_pc = pc + signed(offset, 9)
            elif q == 1 and f3 == 5:  # C.J
                offset = ((half >> 12) & 1) << 11 | ((half >> 11) & 1) << 4 | ((half >> 9) & 3) << 8 | ((half >> 8) & 1) << 10 | ((half >> 7) & 1) << 6 | ((half >> 6) & 1) << 7 | ((half >> 3) & 7) << 1 | ((half >> 2) & 1) << 5
                next_pc = pc + signed(offset, 12)
            else:
                raise ValueError(f"unsupported SDK instruction {half:04x} at {pc:x}")
        regs[0] = 0
        pc = next_pc
    raise ValueError("SDK instruction limit exceeded")


def instructions(code):
    offset = 0
    while offset < len(code):
        half = int.from_bytes(code[offset:offset+2], "little")
        width = 4 if half & 3 == 3 else 2
        require(half & 31 != 31 and offset + width <= len(code), "unsupported/truncated instruction width")
        yield offset, width, int.from_bytes(code[offset:offset+width], "little")
        offset += width


def archive_csr_sequence(archive):
    """Inspect actual compiled monomorph, not source text/unused wrappers."""
    found = []
    members = subprocess.check_output(["ar", "t", str(archive)], text=True).splitlines()
    for member in members:
        if not member.endswith(".o"):
            continue
        data = subprocess.check_output(["ar", "p", str(archive), member])
        elf = ELFFile(io.BytesIO(data))
        for section in elf.iter_sections():
            if not (section.name.startswith(".text.") and "5cache9configure" in section.name):
                continue
            trace = []
            for _, width, word in instructions(section.data()):
                if width == 4 and word & 127 == 0x73 and (word >> 12) & 7:
                    f3, rd, rs1 = (word >> 12) & 7, (word >> 7) & 31, (word >> 15) & 31
                    if f3 == 2 and rs1 == 0:
                        trace.append(["read", word >> 20])
                    elif f3 == 1 and rd == 0:
                        trace.append(["write", word >> 20])
                    else:
                        raise ValueError("unexpected compiled CSR operation")
                elif width == 4 and word in (0x0ff0000f, 0x0000100f):
                    trace.append(["fence" if word == 0x0ff0000f else "fence.i"])
            found.append(dict(member=member, section=section.name, sha256=sha(section.data()), trace=trace))
    require(len(found) == 1, "expected exactly one compiled WS53 Cpu configure monomorph")
    require(found[0]["trace"] == [
        ["read", 0x300], ["read", 0x7c0], ["read", 0x7c6],
        ["write", 0x7c2], ["fence"], ["write", 0x7c0], ["write", 0x7c6],
        ["fence.i"], ["read", 0x7c0], ["read", 0x7c6],
    ], "compiled CSR/fence sequence differs")
    return found[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk", type=Path, required=True)
    parser.add_argument("--runtime-archive", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    commit = subprocess.check_output(["git", "-C", str(args.sdk), "rev-parse", "HEAD"], text=True).strip()
    require(commit == COMMIT, "SDK commit changed")
    lib = (args.sdk / LIB).read_bytes()
    require(sha(lib) == LIB_SHA, "SDK library changed (or Git LFS object absent)")
    member = subprocess.check_output(["ar", "p", str(args.sdk / LIB), "cache.c.obj"])
    require(sha(member) == MEMBER_SHA, "SDK member changed")
    elf = ELFFile(io.BytesIO(member))
    names = ("ArchICacheEnable", "ArchICachePrefetchEnable", "ArchICacheFlush")
    bodies = {name: elf.get_section_by_name(".text." + name).data() for name in names}
    indices = {i for i, section in enumerate(elf.iter_sections()) if section.name in {".text." + n for n in names}}
    relocations = []
    for section in elf.iter_sections():
        if section["sh_type"] not in ("SHT_REL", "SHT_RELA") or section["sh_info"] not in indices:
            continue
        symbols = elf.get_section(section["sh_link"])
        for relocation in section.iter_relocations():
            symbol = symbols.get_symbol(relocation["r_info_sym"])
            require(symbol["st_shndx"] == section["sh_info"] and relocation["r_addend"] == 0, "external SDK relocation")
            relocations.append((elf.get_section(section["sh_info"]).name, relocation["r_offset"], relocation["r_info_type"], symbol["st_value"]))
    # These four local branch/jump relocations are already encoded at their
    # final same-section offsets in the pinned object. No linker relaxation,
    # unresolved calls or arbitrary relocation application is allowed here.
    require(relocations == [
        (".text.ArchICacheEnable", 0xa, 44, 0x1e),
        (".text.ArchICacheEnable", 0x20, 45, 0x18),
        (".text.ArchICachePrefetchEnable", 0x8, 16, 0x20),
        (".text.ArchICachePrefetchEnable", 0x22, 45, 0x1a),
    ], "SDK local branch relocations changed")
    arguments = list(range(256)) + [0x100, 0x10000, 0x80000000, U32]
    results = []
    for name in names[:2]:
        accepted = []
        for arg in arguments:
            rc, events = interpret(bodies[name], arg)
            valid = arg in (0, 2, 4, 6) if name == names[0] else arg < 8
            value = arg | 1 if name == names[0] else (arg << 1) | 1
            csr = 0x7c0 if name == names[0] else 0x7c6
            require((rc, events) == (0, [["write", csr, value]]) if valid else (rc, events) == (1, []), f"SDK argument behavior changed: {name}/{arg}")
            if valid:
                accepted.append(arg)
        results.append(dict(symbol=name, sha256=sha(bodies[name]), tested_arguments=len(arguments), accepted=accepted))
    _, trace = interpret(bodies[names[2]], 0)
    require(trace == [["write", 0x7c2, 4], ["fence", 15, 15]], "SDK invalidation sequence differs")
    # Verify the interpreter refuses unsupported/truncated code rather than
    # inventing success. These do not qualify silicon cache behavior.
    rejected = 0
    for bad in (b"\0\0", b"\x73\x10", b"\x73\x10\xf0\x7f", b"\x01\xa0"):
        try:
            interpret(bad, 0)
        except ValueError:
            rejected += 1
    require(rejected == 4, "interpreter refusal regression")
    runtime = archive_csr_sequence(args.runtime_archive)
    root = Path(__file__).resolve().parents[1]
    report = dict(schema="ws53-icache-sdk-compiled-audit-v1", passed=True,
                  sdk_commit=commit, library_sha256=sha(lib), member_sha256=sha(member),
                  runtime_source_snapshot_sha256=sha((root / "src/chips/ws53/cache.rs").read_bytes()),
                  checker_sha256=sha(Path(__file__).read_bytes()), sdk_cases=results,
                  sdk_invalidate_trace=trace, sdk_local_branch_relocations=relocations,
                  interpreter_refusals=rejected,
                  runtime_archive_sha256=sha(args.runtime_archive.read_bytes()), runtime=runtime,
                  source_to_archive_provenance_attested=False,
                  compiled_csr_scan_is_linear_not_path_proof=True,
                  hardware_executed=False, cache_behavior_modeled=False,
                  maintenance_completion_proved=False, dma_coherence_proved=False)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(dict(passed=True, sdk_cases=2 * len(arguments) + 1, interpreter_refusals=rejected, compiled_csr_sequence=True)))


if __name__ == "__main__":
    main()

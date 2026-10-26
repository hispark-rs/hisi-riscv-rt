#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyelftools==0.32"]
# ///
"""Refusal regressions for the offline compiled WS53 instruction-cache audit."""
import argparse
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile

from elftools.elf.elffile import ELFFile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime-archive", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = Path(__file__).with_name("check-ws53-icache.py")
    spec = importlib.util.spec_from_file_location("icache_audit", source)
    audit = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(audit)
    archive = args.runtime_archive.resolve()
    observed = audit.archive_csr_sequence(archive)
    member = subprocess.check_output(["ar", "p", str(archive), observed["member"]])
    section = ELFFile(io.BytesIO(member)).get_section_by_name(observed["section"])
    start, length = section["sh_offset"], section["sh_size"]
    code = section.data()
    decoded = list(audit.instructions(code))
    csr_offset = next(offset for offset, width, word in decoded if width == 4 and word & 127 == 0x73 and (word >> 12) & 7)
    fence_offset = next(offset for offset, width, word in decoded if width == 4 and word == 0x0ff0000f)
    mutations = []

    def change(name, offset, replacement, diagnostic):
        changed = bytearray(member)
        changed[start + offset:start + offset + len(replacement)] = replacement
        mutations.append((name, bytes(changed), diagnostic))

    word = int.from_bytes(code[csr_offset:csr_offset+4], "little")
    change("wrong-csr", csr_offset, ((word & 0xfffff) | (0x7c1 << 20)).to_bytes(4, "little"), "compiled CSR/fence sequence differs")
    change("missing-fence", fence_offset, (0x13).to_bytes(4, "little"), "compiled CSR/fence sequence differs")
    change("unsupported-csr-operation", csr_offset, ((word & ~0x7000) | 0x4000).to_bytes(4, "little"), "unexpected compiled CSR operation")
    change("truncated-long-instruction", length - 2, b"\x1f\0", "unsupported/truncated instruction width")
    rows = []
    with tempfile.TemporaryDirectory(prefix="ws53-icache-audit-") as temp:
        directory = Path(temp)
        for name, data, expected in mutations:
            obj, bad = directory / "mutated.o", directory / (name + ".a")
            obj.write_bytes(data)
            subprocess.run(["ar", "rcs", str(bad), str(obj)], check=True, capture_output=True)
            try:
                audit.archive_csr_sequence(bad)
            except ValueError as error:
                audit.require(str(error) == expected, f"wrong refusal: {name}: {error}")
                rows.append(dict(case=name, refused=True, diagnostic=str(error)))
            else:
                raise ValueError(f"mutated artifact accepted: {name}")
        for name, objects in (("missing-monomorph", []), ("duplicate-monomorph", ["a.o", "b.o"])):
            bad = directory / (name + ".a")
            for obj in objects:
                (directory / obj).write_bytes(member)
            subprocess.run(["ar", "rcs", str(bad), *objects], cwd=directory, check=True, capture_output=True)
            try:
                audit.archive_csr_sequence(bad)
            except ValueError as error:
                audit.require(str(error) == "expected exactly one compiled WS53 Cpu configure monomorph", f"wrong refusal: {name}: {error}")
                rows.append(dict(case=name, refused=True, diagnostic=str(error)))
            else:
                raise ValueError(f"invalid artifact accepted: {name}")
    report = dict(passed=True, positive=1, refusals=rows,
                  checker_sha256=audit.sha(source.read_bytes()),
                  test_sha256=audit.sha(Path(__file__).read_bytes()),
                  runtime_archive_sha256=audit.sha(archive.read_bytes()), hardware_executed=False)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(dict(passed=True, positive=1, refusals=len(rows))))


if __name__ == "__main__":
    main()

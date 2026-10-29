#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyelftools==0.32"]
# ///
"""Check that the WS53 RAM-function audit consumes one ELF snapshot."""
import argparse
import hashlib
import io
from pathlib import Path
import runpy
import struct
from unittest.mock import patch
from elftools.common.exceptions import ELFError
from elftools.elf.elffile import ELFFile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("elf", type=Path, help="linked WS53 RAM-function ELF")
    args = parser.parse_args()
    image = args.elf.read_bytes()
    api = runpy.run_path(str(Path(__file__).with_name("check-ws53-ram-functions.py")))
    reference = api["validate_bytes"](image)
    if reference["elf_sha256"] != hashlib.sha256(image).hexdigest():
        raise RuntimeError("audit digest differs from input")
    # A second read represents a concurrent replacement. It must never occur.
    with patch.object(Path, "read_bytes", side_effect=[image, b"replacement"]) as read:
        result = api["validate"](args.elf)
    if read.call_count != 1 or result != reference:
        raise RuntimeError("audit reopened or changed its ELF input")
    try:
        api["validate_bytes"](image[:52])
    except (ValueError, ELFError):
        pass  # A truncated ELF may be rejected by either parser or auditor.
    else:
        raise RuntimeError("truncated ELF accepted")
    elf = ELFFile(io.BytesIO(image))
    section_index = next(i for i, s in enumerate(elf.iter_sections()) if s.name == ".ws53.ramtext")
    section = elf.get_section(section_index)
    table = elf.get_section_by_name(".symtab")
    function = next(s for s in table.iter_symbols()
                    if s["st_info"]["type"] == "STT_FUNC" and
                    section["sh_addr"] <= s["st_value"] < section["sh_addr"] + section["sh_size"])
    mutant = bytearray(image)
    section_header = elf["e_shoff"] + section_index * elf["e_shentsize"]
    copy = bytes(section.data())
    loaded_function = section["sh_offset"] + function["st_value"] - section["sh_addr"]
    struct.pack_into("<I", mutant, section_header + 16, len(mutant))
    struct.pack_into("<I", mutant, loaded_function, 0x1000202F)
    mutant.extend(copy)
    try:
        api["validate_bytes"](mutant)
    except ValueError as error:
        if "RAM section does not match file-backed load segment" not in str(error):
            raise
    else:
        raise RuntimeError("aliased RAM section accepted despite unsafe loaded code")
    print("PASS immutable snapshot, truncated ELF and aliased RAM section rejection")


if __name__ == "__main__":
    main()

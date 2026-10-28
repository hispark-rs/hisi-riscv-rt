#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyelftools==0.32"]
# ///
"""Check that the WS53 RAM-function audit consumes one ELF snapshot."""
import argparse
import hashlib
from pathlib import Path
import runpy
from unittest.mock import patch
from elftools.common.exceptions import ELFError


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
    print("PASS immutable RAM audit snapshot and truncated ELF rejection")


if __name__ == "__main__":
    main()

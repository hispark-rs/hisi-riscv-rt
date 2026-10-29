#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyelftools==0.32"]
# ///
"""Audit WS53 RAM placement, retained relocations and direct control flow.

Requires --emit-relocs, no relaxation, and a final unstripped RV32 executable.
Rejects indirect calls, Flash references and unknown relocation types. Numeric
addresses, stack pointer provenance, interrupts/NMI/DMA and controller drain
remain an unsafe caller contract; passing this is not Flash-write approval.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
from elftools.elf.elffile import ELFFile

ITCM = (0x28000, 0x2f000)
FLASH = (0x45d300, 0x670000)
SRAM = (0x20050000, 0x2005ff00)


def require(value, message):
    if not value:
        raise ValueError(message)


def inside(region, start, size=1):
    return region[0] <= start < start + size <= region[1]


def signed(value, bits):
    return value - (1 << bits) if value & (1 << (bits-1)) else value


def validate(path):
    return validate_bytes(Path(path).read_bytes())


def validate_bytes(image):
    """Audit and hash one immutable ELF image supplied by the caller."""
    image = bytes(image)
    with io.BytesIO(image) as stream:
        elf = ELFFile(stream)
        require(elf.elfclass == 32 and elf.little_endian and elf['e_machine'] == 'EM_RISCV'
            and elf['e_type'] == 'ET_EXEC' and elf['e_flags'] == 3, 'RV32 ilp32f executable required')
        section = elf.get_section_by_name('.ws53.ramtext')
        require(section is not None and section['sh_type'] == 'SHT_PROGBITS'
            and section['sh_flags'] & ~0x200000 == 6 and section['sh_size'] > 0,
            'read-only executable RAM section required')
        begin, size = section['sh_addr'], section['sh_size']
        region = (begin, begin+size)
        require(inside(ITCM, begin, size) and begin % 32 == 0, 'RAM function ownership/alignment')
        segments = [s for s in elf.iter_segments() if s['p_type'] == 'PT_LOAD'
            and s['p_vaddr'] == begin and s['p_filesz'] == s['p_memsz'] == size and s['p_flags'] == 5]
        require(len(segments) == 1 and inside(FLASH, segments[0]['p_paddr'], size), 'RAM copy must have a Flash LMA')
        require(section['sh_offset'] == segments[0]['p_offset'] and
            segments[0]['p_offset'] + size <= len(image),
            'RAM section does not match file-backed load segment')
        source = segments[0]['p_paddr']
        table = elf.get_section_by_name('.symtab')
        require(table is not None, 'unstripped symbols required')
        symbols = {s.name:s['st_value'] for s in table.iter_symbols() if s.name}
        require([symbols.get(n) for n in ('__ws53_ramtext_begin', '__ws53_ramtext_end', '__ws53_ramtext_load')]
            == [begin, begin+size, source], 'RAM relocation bounds disagree')
        functions = [s for s in table.iter_symbols() if s['st_info']['type'] == 'STT_FUNC'
            and inside(region, s['st_value'], max(1, s['st_size']))]
        require(functions and all(s['st_size'] for s in functions), 'sized RAM functions required')
        relocs = elf.get_section_by_name('.rela.ws53.ramtext')
        require(relocs is not None and relocs.num_relocations() > 0
            and elf.get_section(relocs['sh_info']).name == section.name, 'retained RAM relocations required (--emit-relocs)')
        target_symbols = elf.get_section(relocs['sh_link'])
        records, calls = [], {}
        for rel in relocs.iter_relocations():
            kind, offset = rel['r_info_type'], rel['r_offset']
            require(inside(region, offset, 2), 'relocation outside RAM section')
            require(kind in (1, 16, 17, 18, 19, 23, 24, 25, 26, 27, 28, 44, 45),
                'unsupported/relaxed RAM relocation: '+str(kind))
            symbol = target_symbols.get_symbol(rel['r_info_sym'])
            require(isinstance(symbol['st_shndx'], int), 'undefined/absolute RAM reference')
            target = symbol['st_value'] + rel['r_addend']
            # This first contract deliberately disallows ordinary data/stack
            # relocations from the closure. Caller arguments can reference RAM,
            # but are outside what a static relocation table can prove.
            require(inside(region, target), 'RAM reference leaves audited section: '+symbol.name)
            records.append(dict(offset=offset, type=kind, symbol=symbol.name, target=target))
            if kind in (18, 19):
                calls[offset] = target
        code = section.data()
        instructions = 0
        for function in functions:
            cursor, end = function['st_value'], function['st_value']+function['st_size']
            while cursor < end:
                offset = cursor-begin
                half = int.from_bytes(code[offset:offset+2], 'little')
                width = 2 if half & 3 != 3 else 4
                require(cursor+width <= end and not (width == 4 and half & 31 == 31), 'truncated/long instruction')
                word = int.from_bytes(code[offset:offset+width], 'little')
                if width == 4:
                    opcode = word & 127
                    require(opcode != 0x2f, 'A-extension instruction in RAM')
                    if opcode == 0x67:
                        ret = word == 0x00008067
                        require(ret or cursor-4 in calls, 'unresolved indirect RAM control flow')
                        if not ret:
                            first = int.from_bytes(code[offset-4:offset], 'little')
                            require(first & 127 == 0x17 and (first >> 7) & 31 == (word >> 15) & 31,
                                'RAM call must be AUIPC/JALR')
                            target = cursor-4 + signed(first & 0xfffff000, 32) + signed(word >> 20, 12)
                            require(target & ~1 == calls[cursor-4], 'encoded RAM call/relocation mismatch')
                    if opcode == 0x6f:
                        imm = ((word >> 31) << 20 | ((word >> 12) & 255) << 12
                            | ((word >> 20) & 1) << 11 | ((word >> 21) & 1023) << 1)
                        require(inside(region, cursor+signed(imm, 21)), 'direct jump leaves RAM')
                    if opcode == 0x63:
                        imm = ((word >> 31) << 12 | ((word >> 7) & 1) << 11
                            | ((word >> 25) & 63) << 5 | ((word >> 8) & 15) << 1)
                        require(inside(region, cursor+signed(imm, 13)), 'branch leaves RAM')
                else:
                    require(word & 0xf07f not in (0x8002, 0x9002) or word == 0x8082,
                        'unresolved compressed indirect control flow')
                    if word & 0xe003 in (0x2001, 0xa001):
                        # c.j/c.jal: imm[11|4|9:8|10|6|7|3:1|5]
                        imm = ((word >> 12 & 1) << 11 | (word >> 11 & 1) << 4
                            | (word >> 9 & 3) << 8 | (word >> 8 & 1) << 10
                            | (word >> 7 & 1) << 6 | (word >> 6 & 1) << 7
                            | (word >> 3 & 7) << 1 | (word >> 2 & 1) << 5)
                        require(inside(region, cursor+signed(imm, 12)), 'compressed jump leaves RAM')
                    if word & 0xe003 in (0xc001, 0xe001):
                        imm = ((word >> 12 & 1) << 8 | (word >> 10 & 3) << 3
                            | (word >> 5 & 3) << 6 | (word >> 3 & 3) << 1 | (word >> 2 & 1) << 5)
                        require(inside(region, cursor+signed(imm, 9)), 'compressed branch leaves RAM')
                instructions += 1
                cursor += width
        return dict(passed=True, elf_sha256=hashlib.sha256(image).hexdigest(),
            begin=begin, end=begin+size, load=source, size=size, instructions=instructions,
            functions={s.name:dict(address=s['st_value'], size=s['st_size']) for s in functions},
            relocations=records, symbols=symbols, hardware_verified=False,
            flash_controller_handoff_verified=False, complete_execution_closure_proven=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('elf', type=Path)
    args = parser.parse_args()
    result = validate(args.elf)
    result.pop('symbols')
    print(json.dumps(result, indent=2))

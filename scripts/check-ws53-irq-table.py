#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyelftools==0.32"]
# ///
"""Bind every SVD-defined WS53 IRQ to its named runtime handler and ELF slot.

Not a device/IRQ-delivery test. Checks the complete declared set, rejects gaps
and mismatched names, and optionally resolves actual linked table words.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import xml.etree.ElementTree as ET
from elftools.elf.elffile import ELFFile


def require(ok,reason):
    if not ok:raise ValueError(reason)


def irq_set(svd):
    result={}
    for p in ET.parse(svd).findall('./peripherals/peripheral'):
        for irq in p.findall('interrupt'):
            name=irq.findtext('name');number=int(irq.findtext('value'),0)
            require(name not in result and number not in result.values(),'duplicate IRQ name/number')
            require(26<=number<90,'IRQ outside WS53 runtime table')
            result[name]=number
    require(result,'empty IRQ source');return result


def bindings(source,expected):
    rows=re.findall(r'table\[Irq::(\w+) as usize\]\s*=\s*(\w+)\s*;',source)
    require(len(rows)==len(expected) and len({a for a,b in rows})==len(rows),'missing/duplicate runtime IRQ slot')
    require(all(a==b for a,b in rows) and {a for a,b in rows}==set(expected),'runtime name/set differs from PAC')
    declarations=re.findall(r'\bfn (\w+)\(\);',source)
    require(all(declarations.count(n)==1 for n in expected),'named IRQ declaration absent/duplicate')


def linked(elf_path,expected):
    with elf_path.open('rb') as stream:
        elf=ELFFile(stream);table=elf.get_section_by_name('.symtab')
        def symbol(name):
            found=table.get_symbol_by_name(name);require(found and len(found)==1,'ELF IRQ symbol '+name);return found[0]
        irq=symbol('__INTERRUPTS');require(irq['st_size']==90*4,'ELF IRQ table size')
        section=elf.get_section(irq['st_shndx']);off=irq['st_value']-section['sh_addr'];raw=section.data()[off:off+360]
        require(len(raw)==360,'ELF IRQ table bytes')
        words=struct.unpack('<90I',raw)
        for name,number in expected.items():require(words[number]==symbol(name)['st_value'],'ELF IRQ slot '+name)
    return {name:words[number] for name,number in expected.items()}


def run(args):
    expected=irq_set(args.svd);source=args.source.read_text();bindings(source,expected)
    refused=[]
    if args.self_test:
        for name in expected:
            changed=re.sub(r'table\[Irq::'+name+r' as usize\]\s*=\s*'+name+r'\s*;','',source)
            try:bindings(changed,expected)
            except ValueError:refused.append('missing '+name)
            else:raise AssertionError('accepted missing slot')
        for name,changed in [('duplicate',source+'\ntable[Irq::APP_INT0 as usize] = APP_INT0;'),
                             ('wrong function',source.replace('= APP_INT0;','= APP_INT1;'))]:
            try:bindings(changed,expected)
            except ValueError:refused.append(name)
            else:raise AssertionError('accepted '+name)
    return dict(passed=True,irq_count=len(expected),irqs=expected,mutations_refused=refused,
        linked_slots=linked(args.elf,expected) if args.elf else None,
        source_sha256=hashlib.sha256(args.source.read_bytes()).hexdigest(),svd_sha256=hashlib.sha256(args.svd.read_bytes()).hexdigest(),
        hardware_accessed=False,irq_delivery_verified=False)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--svd',type=Path,required=True);p.add_argument('--source',type=Path,default=Path(__file__).resolve().parents[1]/'src/chips/ws53.rs')
    p.add_argument('--elf',type=Path);p.add_argument('--self-test',action='store_true')
    print(json.dumps(run(p.parse_args()),indent=2))

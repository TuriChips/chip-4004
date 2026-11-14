#!/usr/bin/env python3
"""Tiny 4004 assembler for the tests. Written from docs/spec.md section 6 only.
Usage: asm.py prog.asm outdir   -> outdir/rom0..7.hex (256 lines of 2 hex digits per 256-byte page)
Syntax: one statement per line, ';' starts a comment, 'label:' defines a label,
        '.org N' sets the address, '.byte V' emits a byte. Numbers: decimal or 0x.. ; labels as operands.
Registers are written r0..r15, pairs p0..p7."""
import sys, os, re

ONE = {  # no operand
    'nop': 0x00, 'wrm': 0xE0, 'wmp': 0xE1, 'wrr': 0xE2, 'wpm': 0xE3,
    'wr0': 0xE4, 'wr1': 0xE5, 'wr2': 0xE6, 'wr3': 0xE7, 'sbm': 0xE8, 'rdm': 0xE9,
    'rdr': 0xEA, 'adm': 0xEB, 'rd0': 0xEC, 'rd1': 0xED, 'rd2': 0xEE, 'rd3': 0xEF,
    'clb': 0xF0, 'clc': 0xF1, 'iac': 0xF2, 'cmc': 0xF3, 'cma': 0xF4, 'ral': 0xF5,
    'rar': 0xF6, 'tcc': 0xF7, 'dac': 0xF8, 'tcs': 0xF9, 'stc': 0xFA, 'daa': 0xFB,
    'kbp': 0xFC, 'dcl': 0xFD,
}
REGOP = {'inc': 0x60, 'add': 0x80, 'sub': 0x90, 'ld': 0xA0, 'xch': 0xB0}
IMM = {'bbl': 0xC0, 'ldm': 0xD0}
PAIR = {'src': 0x21, 'jin': 0x31, 'fin': 0x30}

def num(tok, labels, pc, final):
    tok = tok.strip()
    if tok in labels: return labels[tok]
    try: return int(tok, 0)
    except ValueError:
        if final: raise SystemExit(f"unknown symbol {tok!r}")
        return 0

def rng(v, lo, hi, what):
    if not lo <= v <= hi: raise SystemExit(f"{what} {v} out of range {lo}..{hi}")
    return v

def reg(t, k='r'):
    m = re.fullmatch(k + r'(\d+)', t.strip().lower())
    if not m or int(m.group(1)) > (15 if k == 'r' else 7): raise SystemExit(f"bad register {t!r}")
    return int(m.group(1))

def assemble(lines, final, labels):
    mem = {}; pc = 0
    def emit(*b):
        nonlocal pc
        for x in b:
            assert pc not in mem, f"overlap at {pc:#x}"
            mem[pc] = x & 0xFF; pc += 1
    for ln in lines:
        ln = ln.split(';')[0].strip()
        while ':' in ln:
            l, ln = ln.split(':', 1); labels[l.strip()] = pc; ln = ln.strip()
        if not ln: continue
        op, _, rest = ln.partition(' '); op = op.lower(); args = [a for a in rest.split(',') if a.strip()]
        n = lambda i: num(args[i], labels, pc, final)
        def target(i, size):   # byte operand of JCN/ISZ. A label must be on the page of the address after the 2nd word
            v = n(i)           # (spec 6.2, incl. the xFE quirk); a number is taken as the byte itself.
            if args[i].strip() in labels:
                if final and (v >> 8) != ((pc + size) >> 8):
                    raise SystemExit(f"label {args[i].strip()} ({v:#05x}) is not on the page of {(pc + size):#05x}")
                return v & 0xFF
            return rng(v, 0, 255, "branch byte")
        if op == '.org': pc = n(0)
        elif op == '.byte': emit(rng(n(0), 0, 255, '.byte'))
        elif op in ONE: emit(ONE[op])
        elif op in REGOP: emit(REGOP[op] | reg(args[0]))
        elif op in IMM: emit(IMM[op] | rng(n(0), 0, 15, op + ' immediate'))
        elif op in PAIR: emit(PAIR[op] | (reg(args[0], 'p') << 1))
        elif op == 'fim': emit(0x20 | (reg(args[0], 'p') << 1), rng(n(1), 0, 255, 'fim byte'))
        elif op == 'isz': emit(0x70 | reg(args[0]), target(1, 2))
        elif op == 'jcn': emit(0x10 | rng(n(0), 0, 15, 'jcn condition'), target(1, 2))
        elif op == 'jun': a = rng(n(0), 0, 0xFFF, 'address'); emit(0x40 | a >> 8, a)
        elif op == 'jms': a = rng(n(0), 0, 0xFFF, 'address'); emit(0x50 | a >> 8, a)
        else: raise SystemExit(f"unknown mnemonic {op!r}")
    return mem

def main():
    src, out = sys.argv[1], sys.argv[2]
    lines = open(src).read().splitlines(); labels = {}
    assemble(lines, False, labels)
    mem = assemble(lines, True, labels)
    if mem and max(mem) >= 0x800: raise SystemExit(f"byte at {max(mem):#05x}: the testbench has ROM pages 0-7 only (< 0x800)")
    os.makedirs(out, exist_ok=True)
    for page in range(8):   # always write pages 0-7 (testbench has 8 4001s); empty page = NOPs
        with open(f"{out}/rom{page}.hex", "w") as f:
            for i in range(256): f.write(f"{mem.get((page << 8) + i, 0):02X}\n")

if __name__ == '__main__': main()

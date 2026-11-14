#!/usr/bin/env python3
"""Tiny 4004 assembler for our demo programs (Homer). Opcodes are from docs/spec.md section 6.
Usage: asm4004.py prog.asm out.hex   -> out.hex is a 256-line $readmemh image, unused bytes 00 (NOP).
Syntax: one instruction per line, ';' starts a comment, 'label:' defines a label.
Numbers are decimal or 0x hex. Registers are written as the number 0-15, pairs as P0-P7."""
import sys
NOARG = {"NOP":0x00,"WRM":0xE0,"WMP":0xE1,"WRR":0xE2,"WPM":0xE3,"SBM":0xE8,"RDM":0xE9,"RDR":0xEA,"ADM":0xEB,
 "CLB":0xF0,"CLC":0xF1,"IAC":0xF2,"CMC":0xF3,"CMA":0xF4,"RAL":0xF5,"RAR":0xF6,"TCC":0xF7,"DAC":0xF8,
 "TCS":0xF9,"STC":0xFA,"DAA":0xFB,"KBP":0xFC,"DCL":0xFD}
REG = {"INC":0x60,"ADD":0x80,"SUB":0x90,"LD":0xA0,"XCH":0xB0}
IMM = {"BBL":0xC0,"LDM":0xD0}
WR = {"WR0":0xE4,"WR1":0xE5,"WR2":0xE6,"WR3":0xE7,"RD0":0xEC,"RD1":0xED,"RD2":0xEE,"RD3":0xEF}
num = lambda t: int(t, 0)
pair = lambda t: int(t.upper().lstrip("P"))
def assemble(lines):
    items, labels, pc = [], {}, 0
    for ln in lines:
        ln = ln.split(";")[0].strip()
        while ":" in ln:
            l, ln = ln.split(":", 1); labels[l.strip()] = pc; ln = ln.strip()
        if not ln: continue
        m, *a = ln.replace(",", " ").split()
        m = m.upper(); size = 2 if m in ("FIM","JUN","JMS","JCN","ISZ") else 1
        items.append((pc, m, a)); pc += size
    out = bytearray(256)
    val = lambda t: labels[t] if t in labels else num(t)
    for pc, m, a in items:
        if m in NOARG: b = [NOARG[m]]
        elif m in WR: b = [WR[m]]
        elif m in REG: b = [REG[m] | num(a[0])]
        elif m in IMM: b = [IMM[m] | num(a[0])]
        elif m == "SRC": b = [0x20 | (pair(a[0]) << 1) | 1]
        elif m == "JIN": b = [0x30 | (pair(a[0]) << 1) | 1]
        elif m == "FIN": b = [0x30 | (pair(a[0]) << 1)]
        elif m == "FIM": b = [0x20 | (pair(a[0]) << 1), val(a[1]) & 255]
        elif m in ("JUN","JMS"): t = val(a[0]); b = [(0x40 if m == "JUN" else 0x50) | (t >> 8), t & 255]
        elif m == "JCN": b = [0x10 | num(a[0]), val(a[1]) & 255]
        elif m == "ISZ": b = [0x70 | num(a[0]), val(a[1]) & 255]
        else: sys.exit("unknown mnemonic " + m)
        out[pc:pc+len(b)] = bytes(b)
    return out
if __name__ == "__main__":
    img = assemble(open(sys.argv[1]).read().splitlines())
    open(sys.argv[2], "w").write("".join("%02x\n" % x for x in img))

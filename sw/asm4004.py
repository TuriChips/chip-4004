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
class AsmError(Exception): pass
def num(t, lo=0, hi=15, what="value"):
    try: v = int(t, 0)
    except ValueError: raise AsmError("%s '%s' is not a number or known label" % (what, t))
    if not lo <= v <= hi: raise AsmError("%s %d out of range %d..%d" % (what, v, lo, hi))
    return v
def pair(t):
    u = t.upper()
    if not (u.startswith("P") and u[1:].isdigit()): raise AsmError("pair '%s' must look like P0..P7" % t)
    return num(u[1:], 0, 7, "pair")
def need(a, n):
    if len(a) != n: raise AsmError("expected %d operand(s), got %d" % (n, len(a)))
def assemble(lines):
    items, labels, pc = [], {}, 0
    for no, ln in enumerate(lines, 1):
        try:
            ln = ln.split(";")[0].strip()
            while ":" in ln:
                l, ln = ln.split(":", 1); labels[l.strip()] = pc; ln = ln.strip()
            if not ln: continue
            m, *a = ln.replace(",", " ").split()
            m = m.upper(); size = 2 if m in ("FIM","JUN","JMS","JCN","ISZ") else 1
            if pc + size > 256: raise AsmError("instruction ends past byte 255 (one 4001 holds 256 bytes)")
            items.append((no, pc, m, a)); pc += size
        except AsmError as e: sys.exit("line %d: %s" % (no, e))
    out = bytearray(256)
    def val(t, lo, hi, what):
        return labels[t] if t in labels else num(t, lo, hi, what)
    def same_page(t, pc):   # spec 6.2: a short jump stays in the page of the address after its second word
        if (t >> 8) != ((pc + 2) >> 8): raise AsmError("target 0x%03x is not in the page of the next instruction (page %d)" % (t, (pc + 2) >> 8))
        return t & 255
    for no, pc, m, a in items:
        try:
            if m in NOARG: need(a, 0); b = [NOARG[m]]
            elif m in WR: need(a, 0); b = [WR[m]]
            elif m in REG: need(a, 1); b = [REG[m] | num(a[0], 0, 15, "register")]
            elif m in IMM: need(a, 1); b = [IMM[m] | num(a[0], 0, 15, "immediate")]
            elif m == "SRC": need(a, 1); b = [0x20 | (pair(a[0]) << 1) | 1]
            elif m == "JIN": need(a, 1); b = [0x30 | (pair(a[0]) << 1) | 1]
            elif m == "FIN": need(a, 1); b = [0x30 | (pair(a[0]) << 1)]
            elif m == "FIM": need(a, 2); b = [0x20 | (pair(a[0]) << 1), num(a[1], 0, 255, "byte")]
            elif m in ("JUN","JMS"): need(a, 1); t = val(a[0], 0, 4095, "address"); b = [(0x40 if m == "JUN" else 0x50) | (t >> 8), t & 255]
            elif m == "JCN": need(a, 2); b = [0x10 | num(a[0], 0, 15, "condition"), same_page(val(a[1], 0, 4095, "address"), pc)]
            elif m == "ISZ": need(a, 2); b = [0x70 | num(a[0], 0, 15, "register"), same_page(val(a[1], 0, 4095, "address"), pc)]
            else: raise AsmError("unknown mnemonic " + m)
        except AsmError as e: sys.exit("line %d: %s" % (no, e))
        out[pc:pc+len(b)] = bytes(b)
    return out
if __name__ == "__main__":
    img = assemble(open(sys.argv[1]).read().splitlines())
    open(sys.argv[2], "w").write("".join("%02x\n" % x for x in img))

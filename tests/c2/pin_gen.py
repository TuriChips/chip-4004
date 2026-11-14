#!/usr/bin/env python3
"""Expected pin timing (C2, C6) for a straight-line program, from spec section 4 only.
Usage: pin_gen.py prog.asm > prog.pins
Walks the assembled program from address 0 until the first JUN (not emitted). It models only what the pins
need: pc, acc (known after LDM/CLB only), the DCL bank, SRC address, FIM pairs. Anything else that changes acc
makes acc 'unknown'; using an unknown acc for an I/O-write X2 is an error. Supported: NOP LDM CLB DCL FIM SRC
and the I/O group (E0-EF). One line per clock period, starting at A1 of the SECOND instruction cycle
(the testbench aligns on the first sync), a 12-bit hex word: {0, sync, d_oe, cm_rom} cm_ram d_out ('x' = not compared).
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + '/..')
import asm
LINES = [0b0001, 0b0010, 0b0100, 0b0110, 0b1000, 0b1010, 0b1100, 0b1110]   # spec 6.5, bit i = CM-RAMi
WRITES = {0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7}
def main():
    lines = open(sys.argv[1]).read().splitlines()
    mem = asm.assemble(lines, True, {})
    pc = 0; acc = 0; bank = 0; src = 0; pairs = [0] * 8
    out = []; cycle = 0
    def period(oe, dout, rom, ram, sync):
        out.append("%X%X%s" % ((sync << 2) | (oe << 1) | rom, ram, 'x' if dout is None else "%X" % dout))
    def cyc(a, io, is_src, wr, second):
        nonlocal cycle
        cycle += 1
        if cycle == 1: return                       # first cycle is before alignment
        L = LINES[bank]
        period(1, a & 15, 0, 0, 0); period(1, (a >> 4) & 15, 0, 0, 0); period(1, (a >> 8) & 15, 1, L, 0)
        period(0, None, 0, 0, 0); period(0, None, int(io), L if io else 0, 0); period(0, None, 0, 0, 0)
        if is_src: period(1, (src >> 4) & 15, 1, L, 0)
        elif wr:
            if acc is None: raise SystemExit("acc unknown at an I/O write")
            period(1, acc, 0, 0, 0)
        else: period(0, None, 0, 0, 0)
        if is_src: period(1, src & 15, 0, 0, 1)
        else: period(0, None, 0, 0, 1)
    while True:
        op = mem.get(pc, 0); hi, lo = op >> 4, op & 15
        if hi == 4: break                           # JUN: end of the straight-line part
        a = pc
        if hi == 2 and lo % 2 == 0:                 # FIM: two cycles
            b = mem.get(pc + 1, 0); cyc(a, False, False, False, False); cyc(a + 1, False, False, False, True)
            pairs[lo >> 1] = b; pc += 2; continue
        if hi == 2:                                 # SRC
            src = pairs[lo >> 1]; cyc(a, False, True, False, False); pc += 1; continue
        if hi == 0xE:
            cyc(a, True, False, op in WRITES, False)
            if op not in WRITES: acc = None          # reads set acc from outside
            pc += 1; continue
        if op == 0x00: cyc(a, False, False, False, False)
        elif hi == 0xD: cyc(a, False, False, False, False); acc = lo
        elif op == 0xF0: cyc(a, False, False, False, False); acc = 0
        elif op == 0xFD:
            cyc(a, False, False, False, False)
            if acc is None: raise SystemExit("acc unknown at DCL")
            bank = acc & 7                           # takes effect from the next cycle
        else: raise SystemExit("pin_gen: unsupported opcode %02X at %03X" % (op, pc))
        pc += 1
    print("\n".join(out))
main()

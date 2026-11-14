#!/usr/bin/env python3
"""Expected pin timing (C2, C6) for a straight-line program, from spec section 4 only.
Usage: pin_gen.py prog.asm > prog.pins
Walks the assembled program from address 0 until pc reaches the label 'end' (not emitted). It models only what the pins
need: pc, acc (known after LDM/CLB only), the DCL bank, SRC address, FIM pairs. Anything else that changes acc
makes acc 'unknown'; using an unknown acc for an I/O-write X2 is an error. Supported: NOP LDM CLB DCL FIM SRC, all one-word register/accumulator instructions (values tracked where cheap,
otherwise unknown), JCN and ISZ (when the values they test are known), the I/O group (E0-EF),
and unconditional flow: JUN, JMS, BBL (circular stack, spec 3), FIN (second cycle, page rule), JIN. One line per clock period, starting at A1 of the SECOND instruction cycle
(the testbench aligns on the first sync), a 12-bit hex word: {0, sync, d_oe, cm_rom} cm_ram d_out ('x' = not compared).
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + '/..')
import asm
LINES = [0b0001, 0b0010, 0b0100, 0b0110, 0b1000, 0b1010, 0b1100, 0b1110]   # spec 6.5, bit i = CM-RAMi
WRITES = {0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7}
def main():
    lines = open(sys.argv[1]).read().splitlines()
    labels = {}; asm.assemble(lines, False, labels); mem = asm.assemble(lines, True, labels)
    end = labels['end']
    slot = [0] * 4; sp = 0
    acc = 0; cy = 0; bank = 0; src = 0; r = [0] * 16
    class Pairs:                                    # pair p = {r[2p], r[2p+1]} (spec 3); None = unknown
        def __getitem__(self, p):
            if r[2*p] is None or r[2*p+1] is None: raise SystemExit("register pair %d unknown" % p)
            return r[2*p] << 4 | r[2*p+1]
        def __setitem__(self, p, v): r[2*p] = v >> 4; r[2*p+1] = v & 15
    pairs = Pairs(); test_pin = 0                   # tb_pins holds the test pin at 0
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
        pc = slot[sp]
        if pc == end: break
        op = mem.get(pc, 0); hi, lo = op >> 4, op & 15
        a = pc
        if hi in (4, 5):                            # JUN, JMS: two cycles, then pc = {A, B}
            tgt = ((lo << 8) | mem.get(pc + 1, 0))
            cyc(a, False, False, False, False); cyc(a + 1, False, False, False, True)
            if hi == 5: slot[sp] = (pc + 2) & 0xFFF; sp = (sp + 1) % 4
            slot[sp] = tgt; continue
        if hi == 0xC:                               # BBL
            cyc(a, False, False, False, False); acc = lo
            slot[sp] = (pc + 1) & 0xFFF; sp = (sp - 1) % 4; continue
        if hi == 3 and lo % 2 == 1:                 # JIN: pc = {page of next instruction, pair}
            cyc(a, False, False, False, False)
            slot[sp] = (((pc + 1) >> 8) << 8 | pairs[lo >> 1]) & 0xFFF; continue
        if hi == 3:                                 # FIN: second cycle fetches {page of next instr, P0}
            cyc(a, False, False, False, False)
            cyc((((pc + 1) >> 8) << 8) | pairs[0], False, False, False, True)
            pairs[lo >> 1] = None if False else mem.get((((pc + 1) >> 8) << 8) | pairs[0], 0)
            slot[sp] = (pc + 1) & 0xFFF; continue
        if hi == 2 and lo % 2 == 0:                 # FIM: two cycles
            b = mem.get(pc + 1, 0); cyc(a, False, False, False, False); cyc(a + 1, False, False, False, True)
            pairs[lo >> 1] = b; slot[sp] = pc + 2; continue
        if hi == 2:                                 # SRC
            src = pairs[lo >> 1]; cyc(a, False, True, False, False); slot[sp] = pc + 1; continue
        if hi == 0xE:
            cyc(a, True, False, op in WRITES, False)
            if op not in WRITES: acc = None          # reads set acc from outside
            if op in (0xE8, 0xEB): cy = None
            slot[sp] = pc + 1; continue
        if hi in (1, 7):                            # JCN, ISZ: two cycles; same page = page of the address after the 2nd word
            B = mem.get(pc + 1, 0); cyc(a, False, False, False, False); cyc(a + 1, False, False, False, True)
            tgt = (((pc + 2) >> 8) << 8) | B; nxt = (pc + 2) & 0xFFF
            if hi == 1:
                need = [(lo & 4, acc), (lo & 2, cy)]
                if any(m and v is None for m, v in need): raise SystemExit("JCN needs unknown acc/cy at %03X" % pc)
                cond = bool((lo & 4 and acc == 0) or (lo & 2 and cy == 1) or (lo & 1 and test_pin == 0))
                jump = cond != bool(lo & 8)
            else:
                if r[lo] is None: raise SystemExit("ISZ on unknown register at %03X" % pc)
                r[lo] = (r[lo] + 1) & 15; jump = r[lo] != 0
            slot[sp] = tgt if jump else nxt; continue
        if hi in (6, 8, 9, 0xA, 0xB) or (hi == 0xF and lo != 0 and lo != 0xD):   # one-word, no pin effect
            cyc(a, False, False, False, False)
            if hi == 6: r[lo] = None if r[lo] is None else (r[lo] + 1) & 15
            elif hi == 0xA: acc = r[lo]
            elif hi == 0xB: acc, r[lo] = r[lo], acc
            elif hi in (8, 9):
                if None in (acc, cy, r[lo]): acc = cy = None
                else:
                    t = acc + r[lo] + cy if hi == 8 else acc + (15 - r[lo]) + (1 - cy)
                    acc, cy = t & 15, t >> 4
            elif op == 0xF1: cy = 0
            elif op == 0xFA: cy = 1
            elif op == 0xF3: cy = None if cy is None else 1 - cy
            elif op == 0xF4: acc = None if acc is None else acc ^ 15
            elif op == 0xF2:
                if acc is None: cy = None
                else: t = acc + 1; acc, cy = t & 15, t >> 4
            elif op == 0xF7: acc, cy = cy, 0
            else: acc = cy = None                    # RAL RAR DAC TCS DAA KBP: result not tracked
            slot[sp] = pc + 1; continue
        if op == 0x00: cyc(a, False, False, False, False)
        elif hi == 0xD: cyc(a, False, False, False, False); acc = lo
        elif op == 0xF0: cyc(a, False, False, False, False); acc = 0; cy = 0
        elif op == 0xFD:
            cyc(a, False, False, False, False)
            if acc is None: raise SystemExit("acc unknown at DCL")
            bank = acc & 7                           # takes effect from the next cycle
        else: raise SystemExit("pin_gen: unsupported opcode %02X at %03X" % (op, pc))
        slot[sp] = pc + 1
    print("\n".join(out))
main()

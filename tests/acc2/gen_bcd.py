#!/usr/bin/env python3
"""Acceptance test 2, second routine (spec 9.2): "BCD to Binary Conversion" from the MCS-4 Users Manual
(Intel, Feb 1973, Programming Examples, routine C, label BCDBIN, printed p.50). Writes tests/acc2/bcd2bin_<n>.asm/.exp.

Typed in from the page image (listing tile of PDF page 54) and checked against the manual's own description
text; relocated by +0x100 so the page-local bytes are the manual's bytes (asserted below, in octal, from the
listing). Manual semantics (its text): a 3-digit BCD number is in characters 0, 1, 2 of register 0 of RAM chip 0.
IR3 gets the units digit; each unit of the tens digit adds 10 (IR5) to IR2:IR3 and each unit of the hundreds
digit adds 100 (IR4=6, IR5=4); the digits in RAM are counted down to zero (each decrement is written back with
WRM, which the trace shows). The result is the binary number in IR2 (high nibble) and IR3 (low nibble).
Ours, not the manual's: the prologue that stores the digits, the caller, and the read-out (LD 2 / LD 3 / WRR).
Expected results: the number's binary value from python (N >> 4, N & 15), plus the decrement writes the manual's
text describes (digit d writes d-1, d-2, ... 0)."""
import os, sys
d = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, d + '/..'); import asm

ROUTINE = """\
        .org 0x100
bcdbin: fim p0, 0           ; IR(0-1) = 0
        fim p1, 0           ; IR(2-3) = 0
        fim p2, 10          ; IR(4) = 0, IR(5) = 10
        ldm 14
        xch r6              ; IR(6) = 14 (digit counter: two passes)
        src p0              ; RAM address: chip 0, register 0, character 0
        rdm                 ; units digit
        xch r3              ; IR(3) = units
bdgn:   inc r1              ; next character
        src p0
bb1:    rdm                 ; digit
        jcn 4, bb2          ; digit == 0: done with this digit
        dac                 ; digit - 1
        wrm                 ; write it back
        clc
        ld r3
        add r5              ; IR(3) += IR(5)
        xch r3
        ld r2
        add r4              ; IR(2) += IR(4) + carry
        xch r2
        jun bb1
bb2:    fim p2, 100         ; IR(4) = 6, IR(5) = 4
        isz r6, bdgn        ; second pass, then fall through
        bbl 0
"""
# the manual's octal bytes at its addresses 0o0000.. (JUN's first byte differs by relocation: 0o100 vs ours)
MANUAL = {0o000: [0o040, 0o000, 0o042, 0o000, 0o044, 0o012, 0o336, 0o266, 0o041, 0o351, 0o263,
                  0o141, 0o041, 0o351, 0o024, 0o033, 0o370, 0o340, 0o361, 0o243, 0o205, 0o263, 0o242, 0o204, 0o262],
          0o032: [0o015],                                    # JUN's second byte = address of BB1 (0o015)
          0o033: [0o044, 0o144, 0o166, 0o013, 0o300]}        # BB2: FIM P2,100 ; ISZ R6,BDGN ; BBL 0

def check_manual():
    mem = asm.assemble(ROUTINE.splitlines(), True, dict(assemble_labels()))
    for addr, bytes_ in MANUAL.items():
        got = [mem.get(0x100 + addr + k) for k in range(len(bytes_))]
        assert got == bytes_, f"manual bytes at {addr:#o}: listing {[oct(x) for x in bytes_]}, assembled {[oct(x) if x is not None else None for x in got]}"

def assemble_labels():
    labels = {}; asm.assemble(ROUTINE.splitlines(), False, labels); return labels

def program(n):
    dg = [n % 10, n // 10 % 10, n // 100]
    lines = ["; acc2: manual BCD-to-binary routine, N = %d (digits char0..2 = %s)" % (n, dg), "        nop"]
    exp = list(dg)
    for ch, v in enumerate(dg):
        lines += [f"        fim p7, {ch}", "        src p7", f"        ldm {v}", "        wrm"]
    lines += ["        jms bcdbin", "        ld r2", "        wrr", "        ld r3", "        wrr", "end:    jun end", ROUTINE.rstrip("\n")]
    for v in dg[1:]: exp += list(range(v - 1, -1, -1))        # decrement writes: tens, then hundreds
    exp += [n >> 4, n & 15]
    return "\n".join(lines) + "\n", exp

check_manual()
NUMS = (0, 7, 10, 99, 100, 128, 205, 255)
for n in NUMS:
    text, exp = program(n)
    open(f"{d}/bcd2bin_{n}.asm", "w").write(text)
    open(f"{d}/bcd2bin_{n}.exp", "w").write("\n".join("%X" % e for e in exp) + "\n")
print("manual bytes checked; wrote", len(NUMS), "cases")

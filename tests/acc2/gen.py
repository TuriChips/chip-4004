#!/usr/bin/env python3
"""Acceptance test 2 (spec 9.2): the 16-digit decimal addition routine from the MCS-4 Users Manual
(Intel, Feb 1973, "Programming Examples", Routine A, printed manual p.49; ADDIIN). Writes tests/acc2/add16_<case>.asm/.exp.

The routine is typed in from the manual's listing (read from the page image), relocated by +0x100 so every
page-local byte is the manual's byte; the manual's octal bytes for ADDIIN, OVERFL and OVFL1 are asserted below.
The manual's listing uses decimal numbers (NEXT=200, PRINT=350, CLRRAM=300 are decimal: 0310 octal = 200).
What the manual leaves to the user is supplied by us, and is not manual text:
  - the two numbers: A in RAM register 3, B in register 0 of RAM chip 0, one digit per character, least
    significant digit in character 0 (the routine adds register-3 digits into register 0, carry rippling up);
  - NEXT, PRINT, CLRRAM: stubs that log a marker (NEXT: 7, PRINT: F, CLRRAM: E) so the testbench sees them.
Expected results are the decimal sum (python integers), not read from the design. Every WRM logs acc at X2, so
the trace shows the 16 sum digits as the routine writes them. Overflow (carry out of digit 16): the routine
calls PRINT 16 times and CLRRAM, per the listing."""
import os, subprocess, sys
d = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, d + '/..'); import asm

ROUTINE = """\
        .org 0x100
addiin: fim p0, 0           ; IR(0-1) = 0
        fim p2, 48          ; IR(4) = 3, IR(5) = 0
        ldm 0               ; load 0 to AC
        xch r6              ; exchange AC and IR(6)
        clc                 ; clear carry
ad1:    src p2              ; define RAM address (number A digit)
        rdm                 ; read RAM to AC
        src p0              ; define RAM address (number B digit)
        adm                 ; add RAM to AC, carry enabled
        daa                 ; decimal adjust
        wrm                 ; write AC to RAM
        inc r1              ; increment IR(1)
        inc r5              ; increment IR(5)
        isz r6, ad1         ; 16 digits
overfl: jcn 2, xxx          ; carry out: overflow
        jun next
xxx:    ldm 0
        xch r10
ovfl1:  fim p1, 216
        jms print
        isz r10, ovfl1
        fim p2, 0
        jms clrram
        jun next
"""
# the manual's octal bytes, address 0o0000.. (relocated: address + 0o400): ADDIIN to ISZ, then OVERFL.., OVFL1.. (page-local ones)
MANUAL = {0o000: [0o040, 0o000, 0o044, 0o060, 0o320, 0o266, 0o361, 0o045, 0o351, 0o041, 0o353, 0o373, 0o340, 0o141, 0o145, 0o166, 0o007],
          0o021: [0o022, 0o025],                          # JCN 2,XXX (the JUN after it has our NEXT)
          0o025: [0o320, 0o272, 0o042, 0o330],                # XXX: LDM 0, XCH 10, FIM P1,216
          0o033: [0o172, 0o027, 0o044, 0o000]}                # JMS skipped (target is ours); ISZ 10,OVFL1; FIM P2,0

def check_manual():
    src = (ROUTINE + "next: nop\nprint: nop\nclrram: nop\n").splitlines()
    labels = {}
    asm.assemble(src, False, labels)
    labels.update(next=0x200, print=0x25E, clrram=0x22C)
    mem = asm.assemble(src, True, labels)
    for addr, bytes_ in MANUAL.items():
        got = [mem.get(0x100 + addr + k) for k in range(len(bytes_))]
        assert got == bytes_, f"manual bytes at {addr:#o}: listing {[oct(x) for x in bytes_]}, assembled {[oct(x) if x is not None else None for x in got]}"

def digits(n): return [(n // 10**i) % 10 for i in range(16)]    # least significant first

def program(a, b):
    lines = ["; acc2: manual Routine A (16-digit decimal addition), A=%016d B=%016d" % (a, b), "        nop"]
    exp = []
    for reg, n in ((3, a), (0, b)):                              # prologue: load the numbers
        for ch, dg in enumerate(digits(n)):
            lines += [f"        fim p5, {reg*16 + ch}", "        src p5", f"        ldm {dg}", "        wrm"]; exp.append(dg)
    lines += ["        jun addiin", ROUTINE.rstrip("\n")]
    s = a + b
    exp += digits(s % 10**16)
    lines += ["        .org 0x200", "next:   ldm 7", "        wrr", "end:    jun end",
              "        .org 0x22C", "clrram: ldm 14", "        wrr", "        bbl 0",
              "        .org 0x25E", "print:  ldm 15", "        wrr", "        bbl 0"]
    if s >= 10**16: exp += [15] * 16 + [14]
    exp.append(7)
    return "\n".join(lines) + "\n", exp

CASES = {'ripple': (4999999999999999, 1), 'mixed': (1234567890123456, 5432109876543210),
         'zero': (0, 0), 'overflow': (9999999999999999, 1), 'overflow2': (8765432109876543, 8765432109876543)}
check_manual()
for name, (a, b) in CASES.items():
    text, exp = program(a, b)
    open(f"{d}/add16_{name}.asm", "w").write(text)
    open(f"{d}/add16_{name}.exp", "w").write("\n".join("%X" % e for e in exp) + "\n")
print("manual bytes checked; wrote", len(CASES), "cases")

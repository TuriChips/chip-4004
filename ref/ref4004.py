#!/usr/bin/env python3
"""Reference model of an MCS-4 system (4004 + 4001 ROMs + 4002 RAMs). Owner: Beru.

Written from docs/spec.md (v1) only, never from the RTL. Clock-period accurate at the
pins of spec section 4: one call to System.step() = one rising clk edge = one clock period.

What step() returns, for the period that just ended (the values a testbench sees before
the edge):
  Pins(period, sync, cm_rom, cm_ram, d_oe, d_out, bus, conflict)
    period   0..7 = A1 A2 A3 M1 M2 X1 X2 X3, or None while reset = 1
    d_out    None where spec section 4 says "-" (d_oe = 0: not compared)
    bus      the resolved bus of spec section 2
    conflict True when two or more chips drive (spec section 7, Decision C)
  While reset = 1 the pins are the fixed values of spec section 5.

Instruction-level view (acceptance test 3): System.retired is a list of
(addr, words, state-after) for each instruction that finished, where state is
(pc, acc, cy, r[16] as a tuple, sp).

Usage:
  ref4004.py selftest      run the spec examples, print PASS/FAIL
"""
import sys
from collections import namedtuple

Pins = namedtuple("Pins", "period sync cm_rom cm_ram d_oe d_out bus conflict")
A1, A2, A3, M1, M2, X1, X2, X3 = range(8)

# spec section 6.5: ram_bank -> CM-RAM lines, bit i = CM-RAMi
DCL_LINES = {0b000: 0b0001, 0b001: 0b0010, 0b010: 0b0100, 0b011: 0b0110,
             0b100: 0b1000, 0b101: 0b1010, 0b110: 0b1100, 0b111: 0b1110}
# spec section 6.4 KBP
KBP = {0: 0, 1: 1, 2: 2, 4: 3, 8: 4}

def is_two_word(w):          # JCN 1x, FIM 2(even), JUN 4x, JMS 5x, ISZ 7x
    opr, opa = w >> 4, w & 15
    return opr in (1, 4, 5, 7) or (opr == 2 and opa % 2 == 0)

def is_fin(w):
    return w >> 4 == 3 and (w & 15) % 2 == 0

def is_src(w):
    return w >> 4 == 2 and (w & 15) % 2 == 1

# spec section 4, X2 classes for OPR = 1110
IO_WRITE = {0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7}   # WRM WMP WRR WPM WR0-3
IO_READ = {0x8, 0x9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF}    # SBM RDM RDR ADM RD0-3
RAM_OPS = {0x0, 0x1, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0xB, 0xC, 0xD, 0xE, 0xF}
ROM_OPS = {0x2, 0xA}                                    # WRR RDR (WPM: nobody)


class Rom4001:
    """spec section 7. Contents 256 bytes, CHIP 0..15, PORT_IN."""
    def __init__(self, chip, data, port_in=False):
        self.chip, self.port_in = chip, port_in
        self.data = list(data) + [0] * (256 - len(data))
        self.reset()

    def reset(self):
        self.sel = 0          # SRC latch, high nibble only (spec 6.3)
        self.port = 0         # port latch (output port)


class Ram4002:
    """spec section 7. One chip: CHIP 0..3, on one CM-RAM line (bank)."""
    def __init__(self, bank, chip):
        self.bank, self.chip = bank, chip
        self.reset()

    def reset(self):
        self.latch = 0x00
        self.port = 0
        self.data = [[0] * 16 for _ in range(4)]
        self.status = [[0] * 4 for _ in range(4)]

    def selected(self):
        return (self.latch >> 6) == self.chip

    def reg(self):
        return (self.latch >> 4) & 3

    def char(self):
        return self.latch & 15


class System:
    def __init__(self, roms, rams=None):
        """roms: list of Rom4001. rams: list of Ram4002 (default: 4 x 4002 on bank 0,
        spec section 7 default build)."""
        self.roms = {r.chip: r for r in roms}
        assert len(self.roms) == len(roms), "two ROMs with one chip number"
        self.rams = rams if rams is not None else [Ram4002(0, c) for c in range(4)]
        self.rom_io_in = {}   # chip -> 4-bit value on its port pins (PORT_IN ROMs)
        self.retired = []
        self._reset_all()

    # ---------------------------------------------------------------- state
    def _reset_all(self):
        self.acc = 0; self.cy = 0
        self.r = [0] * 16     # spec 5: 0 after >= 64 reset edges; we clear at once
        self.slot = [0] * 4; self.sp = 0
        self.src_addr = 0; self.ram_bank = 0
        self.period = A1
        self.kind = "first"   # "first", "second" (2-word), "fin" (FIN data cycle)
        self.w1 = 0           # first word of a pending 2-word instruction / FIN
        self.w1_addr = 0
        self.test_latch = 0
        for c in list(self.roms.values()) + self.rams:
            c.reset()

    @property
    def pc(self):
        return self.slot[self.sp]

    @pc.setter
    def pc(self, v):
        self.slot[self.sp] = v & 0xFFF

    def pair(self, p):
        return (self.r[2 * p] << 4) | self.r[2 * p + 1]

    def set_pair(self, p, v):
        self.r[2 * p], self.r[2 * p + 1] = (v >> 4) & 15, v & 15

    def lines(self):
        return DCL_LINES[self.ram_bank]

    def state(self):
        return (self.pc, self.acc, self.cy, tuple(self.r), self.sp)

    # ---------------------------------------------------------------- cycle
    def _begin_cycle(self):
        """At A1: decide what this cycle fetches (spec 4)."""
        if self.kind == "fin":
            self.addr = (self.pc & 0xF00) | self.pair(0)
        else:
            self.addr = self.pc
        rom = self.roms.get(self.addr >> 8)
        self.byte = rom.data[self.addr & 0xFF] if rom else None   # None: nobody drives M1/M2
        b = self.byte or 0
        first = self.kind == "first"
        self.io = first and (b >> 4) == 0xE
        self.src = first and is_src(b)

    def _drivers_x2(self):
        """Who drives the bus at X2 of an I/O read (spec 4, 6.3, 7). Returns list of values."""
        opa = self.byte & 15
        vals = []
        if opa == 0xA:                                   # RDR: the selected ROM
            for rom in self.roms.values():
                if rom.chip == rom.sel:
                    vals.append(self.rom_io_in.get(rom.chip, 0) & 15 if rom.port_in else 0)
        elif opa in RAM_OPS:
            lines = self.lines()
            for ram in self.rams:
                if (lines >> ram.bank) & 1 and ram.selected():
                    if opa in (0x8, 0x9, 0xB):
                        vals.append(ram.data[ram.reg()][ram.char()])
                    else:
                        vals.append(ram.status[ram.reg()][opa - 0xC])
        return vals

    def _pins(self):
        """Pin values in the current period (before the edge)."""
        p = self.period
        sync = 1 if p == X3 else 0
        cm_rom, cm_ram, d_oe, d_out = 0, 0, 0, None
        others = []                                      # values driven by ROM/RAM
        if p in (A1, A2, A3):
            d_oe, d_out = 1, (self.addr >> (4 * p)) & 15
            if p == A3:
                cm_rom, cm_ram = 1, self.lines()
        elif p in (M1, M2):
            if self.byte is not None:
                others.append(self.byte >> 4 if p == M1 else self.byte & 15)
            if p == M2 and self.io:
                cm_rom, cm_ram = 1, self.lines()
        elif p == X2:
            if self.src:
                d_oe, d_out = 1, self.pair((self.byte & 15) >> 1) >> 4
                cm_rom, cm_ram = 1, self.lines()
            elif self.io and (self.byte & 15) in IO_WRITE:
                d_oe, d_out = 1, self.acc
            elif self.io and (self.byte & 15) in IO_READ:
                others = self._drivers_x2()
        elif p == X3:
            if self.src:
                d_oe, d_out = 1, self.pair((self.byte & 15) >> 1) & 15
        drivers = len(others) + d_oe
        if d_oe:
            bus = d_out
        elif others:
            bus = others[0]
            for v in others[1:]:
                bus |= v      # undefined by spec (Decision C); flagged as conflict
        else:
            bus = 0
        return Pins(p, sync, cm_rom, cm_ram, d_oe, d_out, bus, drivers > 1)

    def step(self, reset=0, test=0):
        """One rising clk edge. Returns the Pins of the period that ended."""
        if reset:
            self._reset_all()
            return Pins(None, 0, 0, 0, 0, None, 0, False)
        if self.period == A1:
            self._begin_cycle()
        pins = self._pins()
        p = self.period
        # ---- what the ROMs and RAMs latch at this edge (spec 7, 6.3)
        if p == X2 and self.src:
            for rom in self.roms.values():
                rom.sel = pins.bus
            for ram in self.rams:
                if (pins.cm_ram >> ram.bank) & 1:
                    ram.latch = (pins.bus << 4) | (ram.latch & 15)
                    ram._took_src = True
                else:
                    ram._took_src = False
        if p == X3 and self.src:
            for ram in self.rams:
                if getattr(ram, "_took_src", False):
                    ram.latch = (ram.latch & 0xF0) | pins.bus
        if p == X2 and self.io:
            self._io_x2(pins.bus)
        if p == X2:
            self.x2_bus = pins.bus
        if p == X3 and self.kind == "first" and (self.byte or 0) >> 4 == 1:
            self.test_latch = test & 1        # spec 4: JCN samples TEST at end of X3, cycle 1
        if p == X3:
            self._end_cycle()
            self.period = A1
        else:
            self.period = p + 1
        return pins

    def _io_x2(self, bus):
        """Writes by ROM/RAM at X2 of an I/O instruction (bus = acc for writes)."""
        opa = self.byte & 15
        if opa == 0x2:                                   # WRR
            for rom in self.roms.values():
                if rom.chip == rom.sel and not rom.port_in:
                    rom.port = bus
        elif opa in RAM_OPS and opa in IO_WRITE:
            lines = self.lines()
            for ram in self.rams:
                if (lines >> ram.bank) & 1 and ram.selected():
                    if opa == 0x0:
                        ram.data[ram.reg()][ram.char()] = bus
                    elif opa == 0x1:
                        ram.port = bus
                    else:
                        ram.status[ram.reg()][opa - 0x4] = bus

    def _end_cycle(self):
        """End of X3: the instruction's effect on 4004 state (spec 6)."""
        b = self.byte or 0
        if self.kind == "fin":
            self.set_pair((self.w1 & 15) >> 1, b)        # pc does not advance
            self.kind = "first"
            self._retire(self.w1_addr, (self.w1,))
            return
        here = self.addr
        self.pc = self.pc + 1                            # one word fetched
        if self.kind == "second":
            self._exec2(self.w1, b)
            self.kind = "first"
            self._retire(self.w1_addr, (self.w1, b))
            return
        if is_two_word(b):
            self.kind, self.w1, self.w1_addr = "second", b, here
        elif is_fin(b):
            self.kind, self.w1, self.w1_addr = "fin", b, here
        else:
            self._exec1(b)
            self._retire(here, (b,))

    def _retire(self, addr, words):
        self.retired.append((addr, words, self.state()))

    def _exec1(self, w):
        opr, opa = w >> 4, w & 15
        R = self.r[opa]
        if opr == 0x0:
            pass                                         # NOP (00); 01-0F not in spec 6.1
        elif opr == 0x2:                                 # SRC (odd OPA)
            self.src_addr = self.pair(opa >> 1)
        elif opr == 0x3:                                 # JIN (odd OPA)
            self.pc = (self.pc & 0xF00) | self.pair(opa >> 1)
        elif opr == 0x6:
            self.r[opa] = (R + 1) & 15
        elif opr == 0x8:
            t = self.acc + R + self.cy; self.acc, self.cy = t & 15, t >> 4
        elif opr == 0x9:
            t = self.acc + (~R & 15) + (1 - self.cy); self.acc, self.cy = t & 15, t >> 4
        elif opr == 0xA:
            self.acc = R
        elif opr == 0xB:
            self.acc, self.r[opa] = R, self.acc
        elif opr == 0xC:                                 # BBL
            self.sp = (self.sp - 1) % 4
            self.acc = opa
        elif opr == 0xD:
            self.acc = opa
        elif opr == 0xE:
            self._exec_io(opa)
        elif opr == 0xF:
            self._exec_acc(opa)

    def _exec_io(self, opa):
        """acc/cy effect of I/O reads; the value is what was on the bus at X2."""
        v = self.x2_bus
        if opa == 0x8:                                   # SBM
            t = self.acc + (~v & 15) + (1 - self.cy); self.acc, self.cy = t & 15, t >> 4
        elif opa == 0xB:                                 # ADM
            t = self.acc + v + self.cy; self.acc, self.cy = t & 15, t >> 4
        elif opa in (0x9, 0xA, 0xC, 0xD, 0xE, 0xF):      # RDM RDR RD0-3
            self.acc = v

    def _exec_acc(self, opa):
        a, c = self.acc, self.cy
        if opa == 0x0: self.acc, self.cy = 0, 0
        elif opa == 0x1: self.cy = 0
        elif opa == 0x2: t = a + 1; self.acc, self.cy = t & 15, t >> 4
        elif opa == 0x3: self.cy = 1 - c
        elif opa == 0x4: self.acc = ~a & 15
        elif opa == 0x5: self.acc, self.cy = ((a << 1) | c) & 15, a >> 3
        elif opa == 0x6: self.acc, self.cy = (c << 3) | (a >> 1), a & 1
        elif opa == 0x7: self.acc, self.cy = c, 0
        elif opa == 0x8: t = a + 15; self.acc, self.cy = t & 15, t >> 4
        elif opa == 0x9: self.acc, self.cy = (10 if c else 9), 0
        elif opa == 0xA: self.cy = 1
        elif opa == 0xB:
            if c or a > 9:
                t = a + 6; self.acc = t & 15; self.cy = c | (t >> 4)
        elif opa == 0xC: self.acc = KBP.get(a, 15)
        elif opa == 0xD: self.ram_bank = a & 7
        # FE, FF: NOP (spec 6.4 Decision)

    def _exec2(self, w1, B):
        opr, opa = w1 >> 4, w1 & 15
        page = self.pc & 0xF00          # pc is already past the second word: spec 6.2 "same page"
        if opr == 0x1:                  # JCN
            c = opa
            cond = ((c >> 2) & 1 and self.acc == 0) or ((c >> 1) & 1 and self.cy == 1) \
                or (c & 1 and self.test_latch == 0)
            if bool(cond) != bool(c >> 3):
                self.pc = page | B
        elif opr == 0x2:                # FIM
            self.set_pair(opa >> 1, B)
        elif opr == 0x4:                # JUN
            self.pc = (opa << 8) | B
        elif opr == 0x5:                # JMS: slot[sp] already = address after B
            self.sp = (self.sp + 1) % 4
            self.pc = (opa << 8) | B
        elif opr == 0x7:                # ISZ
            self.r[opa] = (self.r[opa] + 1) & 15
            if self.r[opa] != 0:
                self.pc = page | B

    # ---------------------------------------------------------------- helpers
    def run_cycles(self, n, test=0):
        out = []
        for _ in range(8 * n):
            out.append(self.step(0, test))
        return out

    def do_reset(self, edges=64):
        for _ in range(edges):
            self.step(1)


# ==================================================================== selftest
def rom_with(prog, base=0, size=4096):
    """prog: dict addr->byte or (addr, bytes) list. Returns list of Rom4001 covering used pages."""
    mem = {}
    for addr, data in prog:
        for i, b in enumerate(data):
            mem[(addr + i) & 0xFFF] = b
    pages = sorted({a >> 8 for a in mem} | {0})
    return [Rom4001(p, [mem.get((p << 8) | i, 0) for i in range(256)]) for p in pages]


def boot(prog, rams=None, **kw):
    s = System(rom_with(prog, **kw), rams)
    s.do_reset()
    return s


def run_instr(s, n, test=0, limit=100000):
    """Run until n more instructions retire."""
    target = len(s.retired) + n
    k = 0
    while len(s.retired) < target:
        s.step(0, test); k += 1
        assert k < limit, "runaway"
    return s


def selftest():
    fails = []
    def check(name, got, want):
        if got != want:
            fails.append(f"{name}: got {got!r}, want {want!r}")

    # --- reset pins (spec 5) and first fetch at 0x000
    s = System(rom_with([(0, [0x00])]))
    for _ in range(64):
        p = s.step(1)
        check("reset pins", (p.d_oe, p.sync, p.cm_rom, p.cm_ram), (0, 0, 0, 0))
    p = s.step(0)
    check("first A1 after reset", (p.period, p.d_oe, p.d_out), (A1, 1, 0))

    # --- pin table for a NOP cycle and an SRC cycle (spec 4), ram_bank 000
    s = boot([(0, [0x22, 0xA7, 0x23, 0x00])])            # FIM P1,0xA7 ; SRC P1 ; NOP
    s.run_cycles(2)                                      # FIM (2 cycles)
    cyc = s.run_cycles(1)                                # SRC at 0x002
    want = [(A1, 0, 0, 0, 1, 2), (A2, 0, 0, 0, 1, 0), (A3, 0, 1, 1, 1, 0),
            (M1, 0, 0, 0, 0, None), (M2, 0, 0, 0, 0, None), (X1, 0, 0, 0, 0, None),
            (X2, 0, 1, 1, 1, 0xA), (X3, 1, 0, 0, 1, 0x7)]
    check("SRC cycle pins", [(p.period, p.sync, p.cm_rom, p.cm_ram, p.d_oe, p.d_out) for p in cyc], want)
    check("SRC M1/M2 bus", (cyc[3].bus, cyc[4].bus), (0x2, 0x3))
    cyc = s.run_cycles(1)                                # NOP
    check("NOP X1-X3 undriven", [(p.d_oe, p.cm_rom, p.cm_ram) for p in cyc[5:]], [(0, 0, 0)] * 3)
    check("NOP sync", [p.sync for p in cyc], [0] * 7 + [1])

    # --- I/O write and read at X2: WRM then RDM, M2 cm lines
    s = boot([(0, [0x20, 0x00, 0x21, 0xD9, 0xE0, 0xD0, 0xE9])])  # FIM P0,0;SRC P0;LDM 9;WRM;LDM 0;RDM
    run_instr(s, 3)
    cyc = s.run_cycles(1)                                # WRM
    check("WRM M2 cm", (cyc[M2].cm_rom, cyc[M2].cm_ram), (1, 1))
    check("WRM X2", (cyc[X2].d_oe, cyc[X2].d_out, cyc[X2].cm_rom), (1, 9, 0))
    run_instr(s, 1)
    cyc = s.run_cycles(1)                                # RDM
    check("RDM X2", (cyc[X2].d_oe, cyc[X2].bus), (0, 9))
    check("RDM acc", s.acc, 9)

    # --- spec 6.3 worked example: DCL 0; SRC P0 (=X); DCL 1; SRC P1 (=Y); DCL 0; RDM reads X
    # X = 0x05 (chip 0, reg 0, char 5), Y = 0x0A (chip 0, reg 0, char 10)
    prog = [0x20, 0x05,       # FIM P0, X=0x05
            0x22, 0x0A,       # FIM P1, Y=0x0A
            0xD0, 0xFD,       # DCL 0
            0x23, 0xD4, 0xE0,  # SRC P1 ; LDM 4 ; WRM   -> char Y = 4
            0x21, 0xD7, 0xE0,  # SRC P0 ; LDM 7 ; WRM   -> char X = 7  (bank 0 latch = X)
            0xD1, 0xFD,       # DCL 1
            0x23,             # SRC P1  (only bank 1 sees it)
            0xD0, 0xFD,       # DCL 0
            0xE9]             # RDM: bank-0 RAM still has X latched -> 7
    s = boot([(0, prog)])
    run_instr(s, 16)
    check("6.3 example reads X", s.acc, 7)
    check("6.3 example src_addr is Y", s.src_addr, 0x0A)

    # --- stack: JMS x4 then BBL x4 (spec 3)
    # main@000: JMS 100 ; then halt loop. sub1@100: JMS 200; BBL 1. sub2@200: JMS 300; BBL 2.
    # sub3@300: JMS 400; BBL 3. sub4@400: BBL 4.
    prog = [(0x000, [0x51, 0x00, 0x40, 0x02]),           # JMS 100 ; r1=002: JUN 002
            (0x100, [0x52, 0x00, 0xC1]),                 # r2=102
            (0x200, [0x53, 0x00, 0xC2]),                 # r3=202
            (0x300, [0x54, 0x00, 0xC3]),                 # r4=302
            (0x400, [0xC4])]
    s = boot(prog)
    run_instr(s, 4)                                       # 4 JMS
    check("after 4 JMS pc", s.pc, 0x400)
    pcs = []
    for _ in range(4):
        run_instr(s, 1); pcs.append(s.pc)
    # BBL4 -> r4=302 (BBL 3) -> 202 (BBL 2) -> 102 (BBL 1) -> slot[0] = 0x401 (after sub4's BBL)
    check("JMSx4/BBLx4 returns", pcs, [0x302, 0x202, 0x102, 0x401])
    check("4th BBL acc", s.acc, 1)

    # --- BBL right after reset: sp 0 -> 3, pc = slot[3] = 0
    s = boot([(0, [0xC5])])
    run_instr(s, 1)
    check("BBL at reset", (s.sp, s.pc, s.acc), (3, 0, 5))

    # --- DAA (spec 6.4)
    for acc, cy, want in [(2, 1, (8, 1)), (9, 0, (9, 0)), (10, 0, (0, 1)), (15, 0, (5, 1)),
                          (9, 1, (15, 1)), (0, 0, (0, 0))]:
        s = boot([(0, [0xD0 | acc, 0xFA if cy else 0xF1, 0xFB])])
        run_instr(s, 3)
        check(f"DAA acc={acc} cy={cy}", (s.acc, s.cy), want)

    # --- SUB borrow sense (spec 6.1)
    s = boot([(0, [0x20, 0x03, 0xD5, 0xF1, 0x91])])        # r1=3; acc=5; cy=0; SUB r1
    run_instr(s, 4)
    check("SUB 5-3 cy0", (s.acc, s.cy), (2, 1))
    s = boot([(0, [0x20, 0x05, 0xD3, 0xF1, 0x91])])        # 3-5
    run_instr(s, 4)
    check("SUB 3-5 cy0", (s.acc, s.cy), (14, 0))

    # --- KBP full table, TCS, DAC
    for a in range(16):
        s = boot([(0, [0xD0 | a, 0xFC])]); run_instr(s, 2)
        check(f"KBP {a}", s.acc, {0: 0, 1: 1, 2: 2, 4: 3, 8: 4}.get(a, 15))
    s = boot([(0, [0xD0, 0xF8])]); run_instr(s, 2)
    check("DAC 0", (s.acc, s.cy), (15, 0))
    s = boot([(0, [0xFA, 0xF9])]); run_instr(s, 2)
    check("TCS cy1", (s.acc, s.cy), (10, 0))

    # --- JCN conditions: C=0000 never jumps, C=1000 always, test sampled
    for c, acc, test, jumps in [(0x0, 0, 0, False), (0x8, 5, 1, True), (0x4, 0, 1, True),
                                (0x4, 3, 1, False), (0x1, 3, 0, True), (0x1, 3, 1, False),
                                (0x9, 3, 1, True), (0xC, 0, 1, False)]:
        s = boot([(0, [0xD0 | acc, 0x10 | c, 0x80])])
        run_instr(s, 2, test=test)
        check(f"JCN C={c:x} acc={acc} test={test}", s.pc == 0x080, jumps)

    # --- page quirk: JCN with first word at 0x0FE jumps within page 1
    s = boot([(0x000, [0x40, 0xFE]), (0x0FE, [0x18, 0x20])])   # JUN 0FE ; JCN 8 (always), 0x20
    run_instr(s, 2)
    check("JCN at xFE -> page x+1", s.pc, 0x120)
    # ISZ at 0x2FE
    s = boot([(0x000, [0x42, 0xFE]), (0x2FE, [0x70, 0x33])])   # r0 = 0 -> 1, jumps
    run_instr(s, 2)
    check("ISZ at xFE -> page x+1", s.pc, 0x333)
    # JIN at 0x1FF
    s = boot([(0x000, [0x20, 0x44, 0x41, 0xFF]), (0x1FF, [0x31])])  # P0=0x44; JUN 1FF; JIN P0
    run_instr(s, 3)
    check("JIN at xFF -> page x+1", s.pc, 0x244)
    # FIN at 0x0FF reads from page 1; FIN P0 overwrites P0
    s = boot([(0x000, [0x20, 0x10, 0x40, 0xFF]), (0x0FF, [0x30]), (0x110, [0x5A])])
    run_instr(s, 3)
    check("FIN P0 at xFF", (s.pair(0), s.pc), (0x5A, 0x100))
    # FIN second cycle pins: A1-A3 = {page, P0}, no pc advance
    s = boot([(0x000, [0x20, 0x34, 0x32]), (0x034, [0x9C])])   # P0=0x34; FIN P1
    run_instr(s, 1)
    s.run_cycles(1)                                           # FIN first cycle
    cyc = s.run_cycles(1)                                     # FIN data cycle
    check("FIN 2nd cycle address", [p.d_out for p in cyc[:3]], [4, 3, 0])
    check("FIN result", (s.pair(1), s.pc), (0x9C, 0x003))

    # --- pc wraps mod 4096: JUN FFF, a NOP there -> 000
    s = boot([(0x000, [0x4F, 0xFF]), (0xFFF, [0x00])])
    run_instr(s, 2)
    check("pc wrap", s.pc, 0x000)

    # --- 4001 ports: WRR to output port, RDR from input port and from output port
    roms = rom_with([(0, [0x20, 0x00, 0x21, 0xD6, 0xE2, 0xEA,      # SRC chip0; LDM 6; WRR; RDR
                          0x20, 0x10, 0x21, 0xEA])])                # SRC chip1; RDR
    roms.append(Rom4001(1, [0] * 256, port_in=True))
    s = System(roms); s.rom_io_in[1] = 0xB; s.do_reset()
    run_instr(s, 4)
    check("WRR output port", roms[0].port, 6)
    run_instr(s, 1)
    check("RDR from output port reads 0", s.acc, 0)
    run_instr(s, 3)
    check("RDR from input port", s.acc, 0xB)

    # --- multi-bank read raises the conflict flag (Decision C)
    rams = [Ram4002(1, 0), Ram4002(2, 0)]
    s = boot([(0, [0xD3, 0xFD, 0x20, 0x00, 0x21, 0xE9])], rams)    # DCL 3 (lines 1,2); SRC; RDM
    pins = run_instr_pins(s, 5)
    check("multi-bank read conflict", any(p.conflict for p in pins), True)

    if fails:
        for f in fails:
            print("FAIL", f)
        print(f"FAIL ref4004 selftest: {len(fails)} failed")
        return 1
    print("PASS ref4004 selftest")
    return 0


def run_instr_pins(s, n):
    target = len(s.retired) + n
    out = []
    while len(s.retired) < target:
        out.append(s.step(0))
    return out


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "selftest":
        sys.exit(selftest())
    print(__doc__)
    sys.exit(2)

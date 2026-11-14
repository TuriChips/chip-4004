#!/usr/bin/env python3
"""C9 (spec section 8): random programs, RTL (mcs4_system) vs ref/ref4004.py, every pin every clock.

Usage: tests/random/c9/run.py [--nprog N] [--ncyc N] [--seed S] [--out DIR]
Generates N random programs (4096 random bytes each, none of EXCLUDED), random ROM port inputs
and a random TEST bit per instruction cycle (TEST changes only between cycles, spec 4). Runs them
all in one Icarus simulation (tests/random/c9/tb.sv), then compares every period with the model.
Prints PASS or the first mismatches per program with a reproducer path, exits 1 on any mismatch.
"""
import argparse, os, random, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "ref"))
import ref4004 as R  # noqa: E402

PORT_IN = 0xF0F0          # chips 4-7 and 12-15 have input ports; must match tb.sv default
# Bytes the generator never emits: FE, FF (spec 6.4: tests must not depend on them) and 01-0F
# (not defined by spec 6.1; asked on the spec issue). Excluded everywhere, since any byte can be
# reached as a first word by a jump.
EXCLUDED = {0xFE, 0xFF} | set(range(0x01, 0x10))
OPCODES = [b for b in range(256) if b not in EXCLUDED]
FIELDS = "sync cm_rom cm_ram d_oe d_out bus conflict".split()


def gen(rng, ncyc):
    prog = [rng.choice(OPCODES) for _ in range(4096)]
    io_in = [rng.randrange(16) for _ in range(16)]
    tests = [rng.randrange(2) for _ in range(ncyc)]
    # Mid-run resets (spec 5): in about 1 program in 3, 1-3 random cycles get a reset raised at a
    # random period. Encoded with TEST: bit 1 = reset in this cycle, bits 4:2 = period.
    if rng.random() < 1 / 3:
        for c in rng.sample(range(1, ncyc), rng.randint(1, 3)):
            tests[c] |= 2 | (rng.randrange(8) << 2)
    return prog, io_in, tests


def write(pdir, prog, io_in, tests):
    os.makedirs(pdir, exist_ok=True)
    for n in range(16):
        with open(f"{pdir}/rom{n}.hex", "w") as f:
            f.write("\n".join(f"{b:02x}" for b in prog[256 * n:256 * (n + 1)]) + "\n")
    word = 0
    for n, v in enumerate(io_in):
        word |= v << (4 * n)
    with open(f"{pdir}/stim.hex", "w") as f:
        f.write(f"{word:016x}\n" + "\n".join(f"{t:02x}" for t in tests) + "\n")


MNEM = {0x0: "NOP", 0x1: "JCN", 0x4: "JUN", 0x5: "JMS", 0x6: "INC", 0x7: "ISZ", 0x8: "ADD",
        0x9: "SUB", 0xA: "LD", 0xB: "XCH", 0xC: "BBL", 0xD: "LDM"}
IO = "WRM WMP WRR WPM WR0 WR1 WR2 WR3 SBM RDM RDR ADM RD0 RD1 RD2 RD3".split()
ACC = "CLB CLC IAC CMC CMA RAL RAR TCC DAC TCS STC DAA KBP DCL FE FF".split()


def mnem(w):
    opr, opa = w >> 4, w & 15
    if opr == 0x2: return "SRC" if opa & 1 else "FIM"
    if opr == 0x3: return "JIN" if opa & 1 else "FIN"
    if opr == 0xE: return IO[opa]
    if opr == 0xF: return ACC[opa]
    if opr == 0x0 and opa: return "0x"          # 01-0F: not in spec 6.1
    return MNEM[opr]


def coverage(s, cov):
    """Count instructions and spec corner cases seen by the model (behaviours to target)."""
    prev_sp = 0
    for addr, words, st in s.retired:
        m = mnem(words[0]); cov[m] = cov.get(m, 0) + 1
        sp = st[4]
        ev = []
        if m == "JMS" and sp == 0: ev.append("stack: 4th JMS wraps sp")
        if m == "BBL" and prev_sp == 0: ev.append("stack: BBL with sp=0 (underflow)")
        if m in ("JCN", "ISZ") and (addr & 0xFF) == 0xFE: ev.append("page quirk: 2-word at xFE")
        if m in ("FIN", "JIN") and (addr & 0xFF) == 0xFF: ev.append("page quirk: FIN/JIN at xFF")
        if m in IO and s.ram_bank in (3, 5, 6, 7): ev.append("I/O with multi-line DCL")
        if m in IO and m not in ("WRR", "RDR", "WPM"):
            hit = (R.DCL_LINES[s.ram_bank] >> s.rams[0].bank) & 1
            ev.append("RAM op, populated bank selected" if hit else "RAM op, empty bank selected")
        if (addr & 0xFFF) == 0xFFF: ev.append("pc wrap at FFF")
        for e in ev: cov[e] = cov.get(e, 0) + 1
        prev_sp = sp


def model_pins(prog, io_in, tests, cov=None, ram_bank=0):
    roms = [R.Rom4001(n, prog[256 * n:256 * (n + 1)], port_in=bool((PORT_IN >> n) & 1)) for n in range(16)]
    s = R.System(roms, [R.Ram4002(ram_bank, c) for c in range(4)])
    s.rom_io_in = {n: io_in[n] for n in range(16)}
    out = []
    RESET = ("R", "0", "0", "0000", "0")     # spec 5: pins while reset = 1
    for _ in range(64):
        s.step(1)
        out.append(RESET)
    for v in tests:
        t, rst, rp = v & 1, (v >> 1) & 1, (v >> 2) & 7
        for k in range(8):
            if rst and k == rp:
                for _ in range(64):           # spec 5: only the fixed reset pins are compared
                    s.step(1)
                    out.append(RESET)
                break
            p = s.step(0, t)
            out.append(("%d" % p.sync, "%d" % p.cm_rom, format(p.cm_ram, "04b"), "%d" % p.d_oe,
                        None if p.d_out is None else format(p.d_out, "04b"),
                        format(p.bus, "04b"), "%d" % int(p.conflict)))
    if cov is not None:
        coverage(s, cov)
    return out


def compare(pdir, want):
    got = [l.split() for l in open(f"{pdir}/pins.txt")]
    errs = []
    if len(got) != len(want):
        errs.append(f"length: rtl {len(got)} periods, model {len(want)}")
    cyc = 0; per = 0
    for i, (g, w) in enumerate(zip(got, want)):
        if w[0] == "R" or g[0] == "R":
            if g != list(w):
                errs.append(f"line {i} (reset held): rtl {' '.join(g)} model {' '.join(w)} "
                            "(R sync cm_rom cm_ram d_oe)")
                break
            per = 0
            continue
        where = f"after-reset cycle {cyc} period {'A1 A2 A3 M1 M2 X1 X2 X3'.split()[per]}"
        per += 1
        if per == 8:
            per = 0; cyc += 1
        for k, name in enumerate(FIELDS):
            if name == "d_out" and w[k] is None:
                continue                      # spec 4: "-" = not compared
            if g[k] != w[k]:
                errs.append(f"line {i}, {where}: {name} rtl={g[k]} model={w[k]}")
        if errs:
            break                             # first diverging period is what matters
    return errs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--nprog", type=int, default=100)
    ap.add_argument("--ncyc", type=int, default=1000)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "c9"))
    ap.add_argument("--ram-bank", type=int, default=0, choices=range(4), help="bank holding the 4 x 4002")
    ap.add_argument("--rtl", default=os.path.join(ROOT, "rtl"), help="RTL directory under test")
    ap.add_argument("--extra", nargs="*", default=[], help="extra Verilog files (e.g. PDK cell models)")
    ap.add_argument("--define", nargs="*", default=[], help="iverilog defines, e.g. FUNCTIONAL UNIT_DELAY=")
    a = ap.parse_args()
    rng = random.Random(a.seed)
    os.makedirs(a.out, exist_ok=True)
    progs = []
    for p in range(a.nprog):
        prog, io_in, tests = gen(rng, a.ncyc)
        write(f"{a.out}/prog{p}", prog, io_in, tests)
        progs.append((prog, io_in, tests))
    rtl = sorted(os.path.join(dp, f) for dp, _, fs in os.walk(a.rtl) for f in fs if f.endswith(".v"))
    vvp = f"{a.out}/c9.vvp"
    subprocess.run(["iverilog", "-g2012", f"-DRAM_BANK={a.ram_bank}", *[f"-D{d}" for d in a.define], "-o", vvp, *a.extra, *rtl, os.path.join(ROOT, "tests/random/c9/tb.sv")], check=True)
    sim = subprocess.run(["vvp", "-n", vvp, f"+dir={a.out}", f"+nprog={a.nprog}", f"+ncyc={a.ncyc}"],
                         check=True, capture_output=True, text=True)
    print(sim.stdout.strip())
    if "ERROR" in sim.stdout or "WARNING" in sim.stdout or "DONE c9 tb" not in sim.stdout:
        print("FAIL: simulator reported problems (above)")
        return 1
    bad = 0
    cov = {}
    for p, (prog, io_in, tests) in enumerate(progs):
        errs = compare(f"{a.out}/prog{p}", model_pins(prog, io_in, tests, cov, a.ram_bank))
        if errs:
            bad += 1
            if bad <= 10:
                print(f"MISMATCH prog{p} (seed {a.seed}, {a.out}/prog{p}): " + "; ".join(errs[:4]))
    names = sorted(set(MNEM.values()) | set(IO) | set(ACC) | {"SRC", "FIM", "JIN", "FIN"})
    print("coverage (instructions retired by the model): " + ", ".join(f"{n}={cov.get(n, 0)}" for n in names))
    print("coverage (corner cases): " + ", ".join(f"{k}={v}" for k, v in sorted(cov.items()) if k not in names))
    resets = [(v >> 2) & 7 for _, _, tests in progs for v in tests if v & 2]
    print(f"coverage (mid-run resets): {len(resets)} in {sum(any(v & 2 for v in t) for _, _, t in progs)} programs, "
          "by period " + ", ".join(f"{n}={resets.count(i)}" for i, n in enumerate("A1 A2 A3 M1 M2 X1 X2 X3".split())))
    missing = [n for n in names if not cov.get(n) and n not in ("FE", "FF")]
    print("unexercised instructions: " + (", ".join(missing) if missing else "none"))
    print(f"c9: ram_bank={a.ram_bank} seed={a.seed} programs={a.nprog} cycles={a.ncyc} mismatching_programs={bad}")
    print("PASS" if bad == 0 else "FAIL")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())

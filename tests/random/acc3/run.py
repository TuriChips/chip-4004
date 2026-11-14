#!/usr/bin/env python3
"""Acceptance test 3 (spec 9): random programs on an independent 4004 emulator, MAME's mcs40 core
(BSD-3-Clause), compared with ref/ref4004.py instruction by instruction: pc, acc, cy, r0..r15, sp
before every instruction. Owner: Beru. Details and known differences: ref/README.md.

MAME runs its "busicom" machine with OUR program as the five ROMs (0x000-0x4FF); no original ROM
is used. Get MAME without root first: tests/random/acc3/fetch_mame.sh [DIR] (default build/mame).
Usage: tests/random/acc3/run.py [NPROG] [NINSTR] [SEED0]   (env MAME_DIR, default build/mame)
"""
import os, random, re, subprocess, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.environ.get("REF", os.path.join(ROOT, "ref")))
import ref4004 as R  # noqa: E402

MAME_DIR = os.path.abspath(os.environ.get("MAME_DIR", os.path.join(ROOT, "build", "mame")))


def mame_env():
    root = os.path.join(MAME_DIR, "root")
    libs = sorted({dp for dp, _, fs in os.walk(root) for f in fs if ".so" in f})
    plat = next((dp for dp, ds, _ in os.walk(root) if os.path.basename(dp) == "platforms"), None)
    xdg = os.path.join(MAME_DIR, "xdg")
    os.makedirs(xdg, mode=0o700, exist_ok=True)
    env = dict(os.environ, LD_LIBRARY_PATH=":".join(libs), QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=xdg)
    if plat:
        env["QT_PLUGIN_PATH"] = os.path.dirname(plat)
    return os.path.join(root, "usr", "games", "mame"), env

ROMNAMES = ["busicom.l01", "busicom.l02", "busicom.l05", "busicom.l07", "busicom.l11"]  # pages 0-4
EXCLUDED = {0xFE, 0xFF, 0xEA} | set(range(0x01, 0x10))   # undefined bytes; RDR (keyboard port)
OPCODES = [b for b in range(256) if b not in EXCLUDED]
LINE = re.compile(r"pc=([0-9A-F]+) a=([0-9A-F]) cy=([0-9A-F]) t=([0-9A-F]) sp=([0-9A-F]) r=([0-9A-F]{16}) \|")


def gen(rng):
    """Random bytes for pages 0-4. JUN/JMS targets are kept in pages 0-4 (MAME's busicom has no ROM
    above 0x4FF, so a jump there just slides through FF). JIN is made 8x rarer (a JIN to itself is an
    endless loop that ends the useful part of the run). DCL is thinned out (see the spec 6.3 stop rule)."""
    out = []
    while len(out) < 5 * 256:
        b = rng.choice(OPCODES)
        if b >> 4 == 3 and b & 1 and rng.random() < 7 / 8:
            continue                                   # JIN, mostly skipped
        if b == 0xFD:
            # A DCL away from bank 0 followed by SRC ends the comparison (spec 6.3 stop rule), so
            # half of the DCLs are dropped and half of the rest select bank 0 (LDM 0; DCL).
            if rng.random() < 1 / 2:
                continue
            if rng.random() < 1 / 2:
                out.append(0xD0)
        if b >> 4 in (4, 5):
            b = (b & 0xF0) | ((b & 15) % 5)            # JUN/JMS page 0-4
        out.append(b)
    return out


def run_mame(prog, work, seconds=1):
    rd = os.path.join(work, "roms", "busicom")
    os.makedirs(rd, exist_ok=True)
    for k, n in enumerate(ROMNAMES):
        open(os.path.join(rd, n), "wb").write(bytes(prog[256 * k:256 * (k + 1)]))
    lo = ",".join(f"r{i}" for i in range(8))
    # MAME names R8..RF in hex, and "rc" is the latched ROM-chip register, not R12: read R12/R13
    # through the pair symbol rcrd
    hi = "r8,r9,ra,rb,rcrd,re,rf"
    fmt = "pc=%03X a=%X cy=%X t=%X sp=%X r=" + "%02X" * 8 + " | "
    log = os.path.join(work, "trace.log")
    if os.path.exists(log):
        os.remove(log)
    script = os.path.join(work, "s.txt")
    f1 = "pc=%03X a=%X cy=%X t=%X sp=%X "
    f2 = "%X" * 8
    open(script, "w").write(f'trace {log},maincpu,noloop,{{tracelog "{f1}",pc,a,(curflags>>1)&1,curflags&1,sp;'
                            f'tracelog "r={f2}",{lo};tracelog "%X%X%X%X%02X%X%X | ",{hi}}}\ngo\n')
    mame, env = mame_env()
    # SIGKILL: with the Qt debugger MAME ignores SIGTERM
    subprocess.run(["timeout", "-s", "KILL", "30", mame, "busicom", "-rompath", os.path.join(work, "roms"),
                    "-video", "none", "-sound", "none", "-nothrottle", "-seconds_to_run", str(seconds),
                    "-debug", "-debugger", "qt", "-debugscript", script, "-skip_gameinfo"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
    out = []
    for i, l in enumerate(open(log)):
        m = LINE.match(l)
        if not m:
            raise SystemExit(f"unparsable trace line {i + 1} in {log}: {l.rstrip()}")
        if m:
            pc, a, cy, t, sp, r = m.groups()
            out.append((int(pc, 16), int(a, 16), int(cy, 16), int(t, 16), int(sp, 16),
                        tuple(int(c, 16) for c in r), l.split("|", 1)[1].strip()))
    return out


def model_states(prog, tests, n):
    """State before each instruction, running instruction j with TEST = tests[j]."""
    # MAME's busicom: 4001s on pages 0-4, two 4002s on bank 0 (chips 0, 1; probed), open bus = 15
    roms = [R.Rom4001(k, prog[256 * k:256 * (k + 1)]) for k in range(5)]
    s = R.System(roms, [R.Ram4002(0, 0), R.Ram4002(0, 1)], idle_bus=15)
    s.do_reset()
    states = [(s.pc, s.acc, s.cy, s.sp, tuple(s.r))]
    s.stop_reason = None
    for j in range(n):
        # Known difference (spec 6.3 Decision): our 4002s latch SRC only when their CM-RAM line is
        # active; MAME's system latches it globally. Stop comparing at the first RAM instruction
        # where the two latched addresses differ.
        w = prog[s.pc] if s.pc < len(prog) else 0xFF
        if s.kind == "first" and w >> 4 == 0xE and (w & 15) in R.RAM_OPS and s.rams[0].latch != s.src_addr:
            s.stop_reason = f"instr {j}: RAM op after an SRC the bank-0 RAMs did not see (spec 6.3)"
            break
        t = tests[j] if j < len(tests) else 0
        target = len(s.retired) + 1
        while len(s.retired) < target:
            s.step(0, t)
        states.append((s.pc, s.acc, s.cy, s.sp, tuple(s.r)))
    states_model_stop[0] = s.stop_reason
    return states


states_model_stop = [None]


def compare(prog, tr, n):
    # MAME doesn't trace the first instruction after reset: trace line k = state before instr k+1.
    tests = [None] + [x[3] for x in tr]          # TEST seen before each instruction
    tests[0] = tr[0][3] if tr else 0
    ms = model_states(prog, tests, min(n, len(tr)) + 1)
    for k in range(min(n, len(tr), len(ms) - 1)):
        pc, a, cy, t, sp, r, dis = tr[k]
        want = ms[k + 1]
        got = (pc, a, cy, sp, r)
        if got != want:
            return k, got, want, dis, tr[k - 1][6] if k else ""
    return None


if __name__ == "__main__":
    nprog = int(sys.argv[1]) if len(sys.argv) > 1 else 5
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 2000
    seed0 = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    work = os.path.join(ROOT, "build", "acc3")
    bad = 0
    stopped = 0
    for p in range(nprog):
        rng = random.Random(seed0 + p)
        prog = gen(rng)
        tr = run_mame(prog, work)
        res = compare(prog, tr, n)
        if len(tr) < n:
            bad += 1
            print(f"FAIL seed {seed0 + p}: only {len(tr)} trace lines parsed (need {n}); see {work}/trace.log")
            continue
        if res:
            bad += 1
            k, got, want, dis, prev = res
            print(f"MISMATCH seed {seed0 + p} instr {k}: prev [{prev}] now [{dis}]\n  mame  pc={got[0]:03X} a={got[1]} cy={got[2]} sp={got[3]} r={''.join('%X' % x for x in got[4])}\n  model pc={want[0]:03X} a={want[1]} cy={want[2]} sp={want[3]} r={''.join('%X' % x for x in want[4])}")
        elif states_model_stop[0]:
            stopped += 1
            print(f"ok seed {seed0 + p}: stopped at {states_model_stop[0]}")
        else:
            print(f"ok seed {seed0 + p}: {min(n, len(tr))} instructions")
    print(f"acc3: seed0={seed0} programs={nprog} instructions={n} agree={nprog - bad} "
          f"(stopped early at the spec 6.3 latch difference: {stopped})")
    print("PASS" if bad == 0 else "FAIL")
    sys.exit(1 if bad else 0)

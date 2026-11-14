# ref/: reference model for the 4004 (owner: Beru)

`ref4004.py` models a whole MCS-4 system (4004 + 4001 ROMs + 4002 RAMs), one `step()` per clock
period, at the pins of spec §4. It's written from `docs/spec.md` v1 only, never from the RTL.

- **Pin level** (C2, C9): `System.step(reset, test)` returns `Pins(period, sync, cm_rom, cm_ram,
  d_oe, d_out, bus, conflict)` for each period. `d_out` is `None` where spec §4 says "not compared".
- **Instruction level** (acceptance test 3): `System.retired` lists `(addr, words, state)` per instruction.
- `python3 ref/ref4004.py selftest` checks the spec's own examples: §4 pin table (NOP, SRC, WRM,
  RDM, FIN 2nd cycle), §5 reset pins, §3 stack (JMS×4/BBL×4, BBL at reset), §6.3 per-chip SRC
  example, DAA, SUB borrow sense, KBP table, JCN conditions and TEST, the page quirk for JCN, ISZ,
  JIN and FIN, the pc wrap, 4001 port directions and the multi-bank read conflict.

Not yet here: the C9 random-program generator and the RTL comparison (`tests/random/`). Those need
`mcs4_system` (#16) and the toolchain wiring (#14).

## Acceptance test 3: independent emulator
Requirements: an existing 4004 emulator, not written by us, under a licence that allows running
it in our tests, fetched at test time and never committed (rule 9). The comparison runs on the C9
random programs, at instruction level (`pc`, `acc`, `cy`, `r[0..15]` after each instruction).

### Evaluated 2026-11-14

**pyntel4004 1.2 (PyPI, MIT): rejected as the oracle.** I drove its `Processor` instruction by
instruction against `ref4004.py` on 200 random programs (300 instructions each). Only 16 programs
agreed to the end. Most of the differences are bugs in pyntel4004 itself, not in our spec or model,
confirmed by reading its source:
- `DAC` is wrong for every input: `acc + 15 >= 15` is always true, so it sets `acc = MSB` (= 8)
  and `cy = 1`. Correct: acc 0 → 15 with cy 0; acc 5 → 4 with cy 1 (spec §6.4, manual p.35).
- The program counter is capped at 2048: `jin`/`jun` raise `ProgramCounterOutOfBounds` above 0x7FF,
  because they check against `MEMORY_SIZE_RAM` = 2048 instead of 4096.
- `ISZ` at 0x412 jumped to 0x0DF, so it drops the page (correct: 0x4DF, spec §6.2).
- RAM/status instructions raise `InvalidCommandRegisterContent` when DCL hasn't run (the bank
  register's reset value 0 is "invalid" to it).
- Stack: 3 registers plus a separate PC. That's a legitimate different model from spec §3, but it
  differs after a 4th JMS or a BBL underflow, and random programs do both constantly.
- `JMS` leaves `pc = target − 1` for an external executor that isn't in the package.
With this many of its own bugs, almost every mismatch would measure pyntel4004, not our chip.

**MAME `mcs40` core (`src/devices/cpu/mcs40/mcs40.cpp`, BSD-3-Clause, Vas Crabb): chosen.
Feasibility checked 2026-11-14, works.** It's an independent, widely used implementation of the
4004 at bus-cycle level. Its address stack is a pointer stepping through 4 slots, mod 4
(`push_pc`/`pop_pc`), the same circular model as spec §3, so a 4th JMS and BBL underflow are
comparable. What was checked, on the lab VM, with no root:
- Ubuntu's `mame` 0.264 package plus its 81 missing library packages, fetched with
  `apt-get download` and unpacked with `dpkg-deb -x` (~180 MB, nothing installed system-wide),
  run with `LD_LIBRARY_PATH`. `mame -listfull` lists `i4004` and the 4004 machines `busicom`,
  `4004clk` and `intlc44`.
- `busicom` runs **our own program** when it's given as the 5 ROM files `busicom.l01/l02/l05/l07/l11`
  (0x000–0x4FF). MAME prints "WRONG CHECKSUMS … might not run correctly" and runs anyway.
  No original ROM is needed or used.
- Headless instruction trace: `QT_QPA_PLATFORM=offscreen`, `-video none -sound none -nothrottle
  -seconds_to_run N -debug -debugger qt -debugscript s.txt`, with
  `trace t.log,maincpu,noloop,{tracelog "pc=%03X a=%X cy=%X sp=%X …",pc,a,(curflags>>1)&1,sp,r0,…}`.
  It logs the state **before** each instruction. Debugger symbols: `pc`, `a`, `r0`–`r15`, `sp`,
  `cr`, and `curflags` (bit 1 = carry, bit 0 = TEST). `cy`, `c` and `genflags` don't work as names.
  Check: LDM 15; IAC; IAC; STC; CLC traced as expected (cy = 0 after IAC on 0).
- Gotchas: run under `timeout -s KILL` (it ignores SIGTERM with the Qt debugger); `-seconds_to_run`
  takes whole seconds; the first instruction after reset isn't traced.

**The comparison: `tests/random/acc3/run.py`** (MAME from `tests/random/acc3/fetch_mame.sh`, no root).
Random programs in pages 0–4 run in MAME `busicom` and in `ref4004.py`, compared on
`pc, acc, cy, r0..r15, sp` before every instruction. Harness rules, each matching MAME's
`busicom` machine rather than our default build:
- The model fits 4001s on pages 0–4 only, two 4002s on bank 0 (chips 0 and 1, found with a
  write/read probe over all 8 DCL codes × 4 chips), and `idle_bus=15`. MAME's open bus reads 0xF
  (unmapped ROM fetches `ill $ff`), where our spec §2 says 0000.
- TEST comes from the trace (`curflags` bit 0). The Busicom printer drives it. RDR is excluded
  (the keyboard drives the ROM ports).
- JUN/JMS targets stay in pages 0–4 and JIN is 8× rarer, so the runs execute real code (without
  this, 79% of the instructions were an FF slide).
- **Known difference, spec §6.3:** MAME latches SRC globally, so a RAM on bank 0 sees an SRC sent
  while another bank is selected (the §6.3 example reads Y in MAME, X in our spec). The runner
  stops a program at the first RAM instruction where the two latched addresses differ, and
  reports it as "stopped", not as a pass or a mismatch. Our spec follows the manual (per-chip
  latch); MAME's system models the latch in the CPU.
Other candidates seen, not evaluated: lpg2709/emulator-Intel-4004 (C, MIT, "still in
development"), yurafx/i4004-py (GPL-3.0).

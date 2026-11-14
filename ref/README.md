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

**MAME `mcs40` core (`src/devices/cpu/mcs40/mcs40.cpp`, BSD-3-Clause, Vas Crabb): preferred
candidate, not yet integrated.** It's an independent, widely used implementation of the 4004 at
bus-cycle level (A1–X3, CM lines), so it could even be compared at the pins, not only per
instruction. Open question: how to run it. It's written against MAME's device framework, and
the Debian `mame` package needs a machine with ROM images to start. Next step: a feasibility
check (standalone build of the core with a minimal shim vs. a MAME machine driven through its
debugger trace). The result goes here, and it's the decision for #7.

Other candidates seen, not evaluated: lpg2709/emulator-Intel-4004 (C, MIT, "still in
development"), yurafx/i4004-py (GPL-3.0).

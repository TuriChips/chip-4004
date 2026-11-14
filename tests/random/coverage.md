# Random-test coverage of the 4004 spec (owner: Beru)

What the random tests (C9, acceptance test 3) exercise, mapped to the spec, with numbers and the
log they come from. My "done" is an empty **Gaps** list at the bottom. Directed tests (C1–C8 by
Titus) are tracked in `tests/` and not repeated here.

How the numbers are made: `tests/random/c9/run.py` prints instruction and corner-case counts
for every run, and `tests/random/c9/spec_coverage.py N SEED` counts the §8 combinations on the
model with the same generator and seeds (no RTL needed).

| Spec | Behaviour | Covered by | Numbers | Evidence |
|------|-----------|-----------|---------|----------|
| §8 C9 | RTL = model on every pin, every period, ≥ 10,000 × 1,000 | C9 on main | 10,000 × 1,000, 0 mismatches | `logs/c9-full-20261114T134153Z/SUMMARY.md` |
| §6 / C1 | All 46 instructions | C9 | every instruction in every 500-program batch | `logs/c9-full-20261114T134153Z/shard*-batch*.log` ("unexercised instructions: none") |
| C1 | `cy` in/out for ADD, SUB, ADM, SBM, IAC, DAC, DAA | spec_coverage | all 4 pairs each; DAA 3 (it never clears `cy`, §6.4) | `spec_coverage.py 1000 40000` |
| C1 | KBP, all 16 inputs | spec_coverage | 16/16 | same |
| C2 / §4 | Pins per period, every class, both cycles of 2-word, FIN's 2nd cycle | C9 | all pins compared each period | C9 logs |
| C3 | Page quirk at xFE / xFF | C9 | 2-word at xFE and FIN/JIN at xFF in every batch | `logs/c9-full-20261114T134153Z/*.log` (corner cases) |
| C4 / §3 | Circular stack: 4th JMS wraps, BBL underflow | C9, acc3 (MAME uses the same model) | thousands per batch | C9 logs, `logs/acc3-*` |
| C5 | JCN: 16 codes × acc==0 × cy × TEST (128) | spec_coverage | 128/128 | `spec_coverage.py 1000 40000` |
| C6 / §6.5 | DCL: all 8 codes on SRC and on I/O | spec_coverage | 8/8 and 8/8 | same |
| §5 | Pins while reset is held; reset mid-instruction | C9 | every period of every reset; 6,773 mid-run resets in the full run | `logs/c9-full-20261114T134153Z/SUMMARY.md` |
| C8 | No X/Z on outputs | C9 (4-state Icarus, `d_out` printed in binary) | 0 X/Z | C9 logs |
| §6.3 | Per-chip SRC latch (incl. the §6.3 example) | C9 (RAM on bank 0, 1, 2 or 3), model selftest | 4 bank placements | `logs/c9-banks-*`, `logs/c9-20261114T103058Z` |
| §7 | 4001 ports in both directions (WRR, RDR) | C9 (`ROM_PORT_IN` = 0xF0F0) | both kinds in every run | C9 logs |
| §7 | Writes to several banks at once | C9 `--ram-banks 1,2` | 297 multi-bank writes, 0 mismatches | `logs/c9-multibank-20261114T161008Z/c9-banks12.log` |
| §7 C | Read with two populated banks: `bus_conflict` = 1 | C9 `--ram-banks 1,2` (stops the program at its first conflict) | 42 conflicts, raised every time; mutant (tied 0) caught | `logs/c9-multibank-20261114T161008Z/` |
| §9 test 3 | Independent emulator (MAME `mcs40`) | acc3 | 40 × 3,000 agree; same programs on the RTL, 0 mismatches | `logs/acc3-*`, `logs/c9-acc3progs-*` (#30) |
| §2 build | sky130 gate-level netlist | C9 + demo + Busicom on the netlist | 1,000 × 1,000, 0 mismatches | `logs/c9-gl-sky130-*` (#34) |

## Excluded on purpose (not gaps)
- Bytes 01–0F, FE, FF as first words: spec §6 says tests must not depend on them.
- TEST changing inside a cycle: spec §4 allows changes only at A1.
- A 4001 that isn't fitted: at the compared pins it's the same as a fitted output-port ROM full of
  00 (bus 0000, RDR reads 0000, WRR does nothing), so the all-16-fitted build loses nothing.
- RDR in acceptance test 3: MAME's Busicom keyboard drives the ports. RDR is covered by C9.

## Gaps
None known. One caveat on the numbers: the multi-bank write count (297) is over the whole model
run, while comparison stops at a program's first conflict (42 of 300 programs), so some of those
writes come after a stop and weren't compared. A per-program count up to the stop point would
make this exact. It's a reporting refinement, not a known hole.

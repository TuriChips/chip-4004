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
Not chosen yet. It must be an existing 4004 emulator, not written by us, under a licence that
allows running it in our tests. It's fetched at test time and never committed (rule 9). The choice
and its licence will be recorded here in the PR that adds the comparison.

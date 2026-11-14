# Intel 4004 (1971), rebuilt by AI agents: release write-up, DRAFT

_Draft by Homer. At release this becomes `README.md` (Sai's rule: the README is the write-up). Only claims with a log are in the tables; everything else is under "Not yet". Rows get updated as the other PRs land._

[TuriChips](https://turichips.github.io) is the world's first chip lab run by AI. This is chip #1: the Intel 4004, the first commercial single-chip microprocessor (4-bit, 46 instructions, 16 pins), with its 4001 ROM and 4002 RAM companions. Simulation only; nothing was manufactured.

## Run it yourself
Needs `iverilog`, `verilator`, `yosys` and Python 3 (versions are pinned by the TuriChips toolchain).
```
git clone https://github.com/TuriChips/chip-4004 && cd chip-4004
./sw/run_demo.sh          # decimal addition on the simulated chip, a few seconds
./sw/busicom/run.sh       # the Busicom 141-PF calculator firmware (downloaded at run time), about 5 minutes
```

## Evidence (spec section 9 and 8)
| Check | Result | Log |
|-------|--------|-----|
| Demo: 1294 + 5678 in decimal on `mcs4_system`; the sum 6972 appears on a 4001 port as 2 7 9 6 0 | pass | `logs/demo/add.log` |
| Acceptance test 1: the Busicom 141-PF firmware on `mcs4_system`, with our keyboard and printer model. Sums 18 + 42 = 60, 100 + 35 - = 65, 12 x 12 = 144 | `BUSICOM PASS`: printed lines match `sw/busicom/sums.expected` | `logs/busicom/run.log` (header has the main commit) |
| C9: random programs against the reference model (`ref/ref4004.py`), every pin in every clock period, plus 6,773 mid-run resets | 10,000 programs x 1,000 cycles, 0 mismatching programs (RTL at main 8c91f80) | `logs/c9-full-20261114T134153Z/SUMMARY.md` |

## Size and speed
Generic Yosys (`synth/report.txt`, `synth/logs/yosys.log`) and an open-source sky130 layout (`synth/sky130/`, details and logs in `synth/README.md`):
- Generic synthesis: 1,278 cells (153 flops), longest flop-to-flop path 25 cells.
- sky130: 1,095 cells, 8,637 µm² of cells, 156.9 x 156.9 µm die, 31,101 µm of routed wire, 0 router DRC violations (the router's own count, not a signoff). Longest path 6.931 ns data arrival at an ideal 10 ns clock, slack 2.9 ns, so roughly 140 MHz before any optimization. The original 4004 ran at 740 kHz.
- The real 4004 has about 2,300 transistors; our gates are not transistors, so that comparison is rough.

![Our routed sky130 layout of the 4004](synth/sky130/layout.png)

## Credits
The Busicom firmware is not in this repo; the test downloads it from [4004.com](https://www.4004.com/busicom/). Binaries recovered by Tim McNerney and Fred Huettig with the Computer History Museum; disassembly by Barry Silverman, Brian Silverman and Tim McNerney; commented listing by Lajos Kintli. The commented code is CC BY-NC-SA; the original binary is stated to be uncopyrighted. The spec was checked against Intel's MCS-4 Users Manual, hosted at 4004.com.

## What went wrong along the way
_To fill in from the issue history (Igris's spec decisions, Beru's findings, the busicom harness misreads) before release. Not written yet, so nothing is claimed here._

## Not yet (do not publish until these have logs)
- Behaviour tests C1–C8 (Titus, #6; #13 is open).
- Acceptance test 2 (examples from the Users Manual) and acceptance test 3 (comparison with an independent emulator, Beru #30).
- C9 on the sky130 netlist (Beru, #34) and gate-level Busicom on it.
- Signoff for the layout (timing closure, power, signoff DRC, LVS).
- The keyboard and printer model in the Busicom test is ours, built from the listing's hardware chapter, not Busicom's or Intel's.

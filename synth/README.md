# synth/ (Leo)
Only `i4004` is synthesized. The 4001, 4002 and `mcs4_system` are test fixtures.

## Generic Yosys (`synth/run.sh` → `synth/report.txt`, `synth/logs/yosys.log`)
Gate set AND/NAND/OR/NOR/XOR/XNOR/ANDNOT/ORNOT/MUX, after `memory_map` (the register file and the stack are memories; without `memory_map` Yosys leaves them as `$memrd/$memwr` and the count is wrong).

| Item | Result |
|------|--------|
| Cells | 1278: 153 flops (112 enabled flops for registers and stack, 41 others) and 1125 gates |
| Longest path (flop to flop, `ltp -noff`) | 25 cells, starting at `u_control.second` |
| Warnings, latches | none inferred, `check -assert` clean |

The real 4004 has about 2,300 transistors. Counting differs (our gates are not transistors), so this is a rough comparison only.

## sky130 layout (`synth/sky130/run.sh`, needs `source <toolchain>/scripts/eda-env.sh`)
Yosys maps `i4004` to `sky130_fd_sc_hd` at the typical corner (`lpflow_*`, probe and delay cells filtered out by `filter_lib.py`), OpenROAD places and routes (`flow.tcl`), KLayout writes `i4004.gds` and `layout.png`. The routed run takes about 25 minutes on the lab VM. Tools: OpenROAD 2.0_3175, KLayout 0.30.13, sky130A PDK 1.0.471 (pinned in the toolchain `VERSIONS`).

| Item | Result | Log |
|------|--------|-----|
| Cells after mapping | 1095, of which 153 `dfxtp_1` flops | `sky130/logs/stat.txt` |
| Cell area | 8,637 µm² (8,981 µm² placed with 275 tap cells, 42% utilization) | `sky130/logs/stat.txt`, `sky130/logs/openroad.log` |
| Die | 156.9 × 156.9 µm | `sky130/logs/openroad.log` |
| Routed wire length, vias | 31,101 µm, 9,192 | `sky130/logs/openroad.log` |
| Longest path (typical corner, ideal 10 ns clock) | 6.931 ns data arrival, 0.161 ns setup, slack 2.908 ns (met), 18 cells from `_1922_` to `_1874_` | `sky130/logs/openroad.log` |
| Router DRC violations | 0 (the router's own count, not a signoff) | `sky130/logs/openroad.log` |

The path above implies a clock of about 140 MHz (1 / 7.09 ns) before any optimization. The original 4004 ran at 740 kHz.

Not done: timing closure, power, clock tree (ideal clock), signoff DRC and LVS, gate-level simulation of `i4004_sky130.v`. Power is met1 rails plus met4 straps, 275 tap cells, no fill or decap: fine for a picture and a first run, not for fabrication. `synth/sky130/layout.png` is the image for the website card.

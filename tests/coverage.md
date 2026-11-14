# Coverage: spec behaviour -> test

Spec: docs/spec.md v1. Status per row: **done** (test written), **partial**, **todo**. Nothing here is "passing" until a log in `logs/` says so; the RTL for the chip is not on main yet, so no test has run against a design.

| Spec | Behaviour | Test | Status |
|------|-----------|------|--------|
| C1 | CLB CLC IAC CMC CMA RAL RAR TCC DAC TCS STC DAA KBP (6.4), cy cases of IAC/DAC/DAA | tests/c1/acc_group | done (not yet run) |
| C1 | NOP INC ADD SUB LD XCH BBL LDM | | todo |
| C1 | SRC FIM FIN JIN JCN JUN JMS ISZ | | todo |
| C1 | WRM WMP WRR WPM WR0-3 SBM RDM RDR ADM RD0-3, DCL | | todo |
| C2 | pin timing per class | | todo |
| C3 | page quirk | | todo |
| C4 | stack | | todo |
| C5 | JCN conditions | | todo |
| C6 | DCL bank lines | | todo |
| C7 | reset | | todo |
| C8 | no X/Z, no bus_conflict | checked on every run of tb/tb_prog.sv | partial |
| C9 | random | Beru | n/a |
| Acc. 2 | MCS-4 manual example programs | | todo |

Method (tb/tb_prog.sv): a program is assembled by tests/asm.py and runs on `mcs4_system`. Every I/O write (WRR etc.) puts acc on the bus at X2; the testbench compares that sequence with the `.exp` file, which is derived from spec section 6 by hand, not from any RTL. cy is read out with TCC.

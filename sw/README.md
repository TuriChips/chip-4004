# sw/: demo programs (Homer)
- `asm4004.py`: small assembler for the 4004 instruction table in `docs/spec.md` section 6. `python3 sw/asm4004.py sw/add.asm sw/add.hex`. It stops with the line number on a bad operand (register 0-15, pair P0-P7, immediate 0-15, byte 0-255, address 0-4095), an unknown label or mnemonic, an image longer than 256 bytes, and a JCN/ISZ target outside the page of the next instruction (spec 6.2).
- `add.asm`: adds 1294 + 5678 in decimal (ADD + DAA) and writes the sum digits, least significant first, to the 4001 number 0 I/O port with WRR. The expected port writes are in `add.expected` (2, 7, 9, 6, then carry 0), i.e. 6972. Digit 0 takes its carry from DAA, digit 1 from ADD itself, so both paths run.
- `add.hex`: the assembled 256-byte ROM image for `$readmemh` (`add.asm` is the source; rebuild it with the command above).

**Runner note:** the program writes to 4001 number 0 (`SRC P7` with r14 = r15 = 0), so that 4001's I/O port must be configured as output (`PORT_IN` = 0).

- `demo_tb.sv`, `run_demo.sh`: `./sw/run_demo.sh` assembles `add.asm`, runs it on `mcs4_system` in Icarus, prints each change of 4001 #0's port, and compares the sequence with `add.expected`. Log: `logs/demo/add.log`.

Status: on a scratch merge of the open RTL branches (Ada's datapath and 4001/4002, Zura's control and system) the demo printed `2 7 9 6 0` and passed. That log is not committed, because the RTL is not on main yet. The demo log gets committed once it is.

# sw/: demo programs (Homer)
- `asm4004.py`: small assembler for the 4004 instruction table in `docs/spec.md` section 6. `python3 sw/asm4004.py sw/add.asm sw/add.hex`. It stops with the line number on a bad operand (register 0-15, pair P0-P7, immediate 0-15, byte 0-255, address 0-4095), an unknown label or mnemonic, an image longer than 256 bytes, and a JCN/ISZ target outside the page of the next instruction (spec 6.2).
- `add.asm`: adds 1294 + 5678 in decimal (ADD + DAA) and writes the sum digits, least significant first, to the 4001 number 0 I/O port with WRR. The expected port writes are in `add.expected` (2, 7, 9, 6, then carry 0), i.e. 6972. Digit 0 takes its carry from DAA, digit 1 from ADD itself, so both paths run.
- `add.hex`: the assembled 256-byte ROM image for `$readmemh` (`add.asm` is the source; rebuild it with the command above).

**Runner note:** the program writes to 4001 number 0 (`SRC P7` with r14 = r15 = 0), so that 4001's I/O port must be configured as output (`PORT_IN` = 0).

Status: the program and its expected output are checked by hand and with a throwaway interpreter of the spec rules. It has not run on the RTL yet, because `mcs4_system` (Zura, #5) is not merged. The one-command runner `sw/run_demo.sh` comes with it.

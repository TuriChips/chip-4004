# sw/: demo programs (Homer)
- `asm4004.py`: small assembler for the 4004 instruction table in `docs/spec.md` section 6. `python3 sw/asm4004.py sw/add.asm sw/add.hex`.
- `add.asm`: adds 1234 + 5678 in decimal (ADD + DAA) and writes the sum digits, least significant first, to the 4001 number 0 I/O port with WRR. The expected port writes are in `add.expected` (2, 1, 9, 6, then carry 0), i.e. 6912.
- `add.hex`: the assembled 256-byte ROM image for `$readmemh` (`add.asm` is the source; rebuild it with the command above).

Status: the program and its expected output are checked by hand and with a throwaway interpreter of the spec rules. It has not run on the RTL yet, because `mcs4_system` (Zura, #5) is not merged. The one-command runner `sw/run_demo.sh` comes with it.

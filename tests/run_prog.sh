#!/usr/bin/env bash
# Usage: tests/run_prog.sh tests/c1/acc_group      (needs <name>.asm and <name>.exp)
# Assembles, builds with Icarus (4-state, so C8 is real) and runs; log in logs/<name>.log.
set -euo pipefail
name=$1; b=build/prog/$(basename "$name"); mkdir -p "$b" logs
python3 tests/asm.py "$name.asm" "$b"
iverilog -g2012 -DROM_FILES_PARAM="\"$b/rom0.hex\"" -o "$b/sim.vvp" tb/tb_prog.sv $(find rtl -name '*.v')
vvp -n "$b/sim.vvp" +EXP="$name.exp" 2>&1 | tee "logs/$(basename "$name").log"
grep -q '^PASS' "logs/$(basename "$name").log"

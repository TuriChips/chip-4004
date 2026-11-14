#!/usr/bin/env bash
# Usage: tests/run_prog.sh tests/c1/acc_group      (needs <name>.asm and <name>.exp)
# Assembles, builds with Icarus (4-state, so C8 is real) and runs; log in logs/<name>.log.
set -euo pipefail
name=$1; b=build/prog/$(basename "$name"); mkdir -p "$b" logs
python3 tests/asm.py "$name.asm" "$b"
defs=(); for n in 0 1 2 3 4 5 6 7; do defs+=("-DROM$n=\"$b/rom$n.hex\""); done
iverilog -g2012 "${defs[@]}" -o "$b/sim.vvp" tb/tb_prog.sv $(find "${RTL_DIR:-rtl}" -name '*.v')
plus=""; [ -f "$name.plus" ] && plus=$(cat "$name.plus")
vvp -n "$b/sim.vvp" +EXP="$name.exp" $plus ${EXTRA_PLUS:-} 2>&1 | tee "logs/$(basename "$name")${LOGSUFFIX:-}.log"
grep -q '^PASS' "logs/$(basename "$name")${LOGSUFFIX:-}.log"

#!/usr/bin/env bash
# Homer: assemble sw/add.asm, run it on mcs4_system in Icarus, compare the port writes with sw/add.expected.
# One command from the repo root: ./sw/run_demo.sh   Output: logs/demo/add.log
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
mkdir -p logs/demo build
python3 sw/asm4004.py sw/add.asm build/demo.hex
SRC=$(find rtl -name '*.v' | sort)
iverilog -g2012 -o build/demo.vvp sw/demo_tb.sv $SRC
{ echo "main commit: $(git rev-parse HEAD)$(git diff --quiet HEAD -- . && echo "" || echo " (+ uncommitted changes)")"; vvp -n build/demo.vvp +MAXCLK="${MAXCLK:-4000}"; } | tee logs/demo/add.log
grep '^port' logs/demo/add.log | awk '{print $2}' > build/demo.got
# the port starts at 0 and every expected value differs from the one before, so each write shows as a change
if diff -u sw/add.expected build/demo.got; then
  echo "DEMO PASS: port writes match sw/add.expected (1294 + 5678 = 6972)" | tee -a logs/demo/add.log
else
  echo "DEMO FAIL" | tee -a logs/demo/add.log; exit 1
fi

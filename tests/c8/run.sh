#!/usr/bin/env bash
# C8 (spec 8): no X or Z on any output, and no bus_conflict, with fully driven inputs, in a 4-state (Icarus) run.
# Runs the whole C1-C7 suite plus acceptance test 2 and the pin tests. tb_prog.sv and tb_pins.sv check, on every
# clock once aligned: every output of mcs4_system (d_out of the 4004 even while d_oe = 0, d_oe, sync, cm_rom, cm_ram,
# bus, rom_io_out, ram_port_out) is free of X/Z, and bus_conflict = 0. Any violation makes that run FAIL.
# Usage: tests/c8/run.sh      exit 1 if any run fails; summary line at the end.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
runs=0; bad=0; xz=0; conf=0
note() { runs=$((runs+1)); case "$2" in PASS*) ;; *) bad=$((bad+1)); echo "FAIL $1: $2";; esac; }
for f in tests/c1/*.asm tests/c3/*.asm tests/c4/*.asm tests/c5/*.asm tests/acc2/*.asm; do
  b=${f%.asm}; out=$(tests/run_prog.sh "$b" 2>&1); note "$b" "$(grep -E '^(PASS|FAIL)' <<<"$out" | head -1)"
  xz=$((xz + $(grep -c 'FAIL C8' <<<"$out"))); conf=$((conf + $(grep -c 'bus_conflict at' <<<"$out")))
done
for t in basic dcl flow ops; do
  out=$(tests/run_pins.sh tests/c2/pins_$t 2>&1); note "pins_$t" "$(grep -E '^(PASS|FAIL)' <<<"$out" | head -1)"
  xz=$((xz + $(grep -c 'FAIL C8' <<<"$out"))); conf=$((conf + $(grep -c 'conflict=1' <<<"$out")))
done
out=$(tests/c7/run.sh 2>&1); tail -1 <<<"$out"; runs=$((runs+8)); [ "$(grep -c PASS <<<"$out")" = 8 ] || bad=$((bad+1))
echo "C8: $runs runs, $bad failing, X/Z reports=$xz, bus_conflict reports=$conf"
[ $bad -eq 0 ]

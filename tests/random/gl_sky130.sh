#!/usr/bin/env bash
# C9 on the sky130 gate-level netlist of the CPU (Beru, #33): synth/sky130/i4004_sky130.v in place
# of the RTL i4004, with the RTL i4001/i4002/mcs4_system around it, PDK functional cell models,
# zero delay, Icarus (4-state, so X/Z after reset shows up as a mismatch; Verilator can't run the
# PDK's mux UDPs). Needs PDK_ROOT (source <toolchain>/scripts/eda-env.sh). SKIP if it's missing.
# Usage: tests/random/gl_sky130.sh [run.py args...]   default: --nprog 50 --ncyc 1000 --seed 1
set -u
cd "$(git rev-parse --show-toplevel)"
cells="${PDK_ROOT:-/nonexistent}/sky130A/libs.ref/sky130_fd_sc_hd/verilog"
net=synth/sky130/i4004_sky130.v
if [ ! -f "$cells/sky130_fd_sc_hd.v" ] || [ ! -f "$net" ]; then
  echo "SKIP gate-level sky130 (need $net and PDK_ROOT with sky130A cell models)"; exit 0
fi
dir=build/gl_sky130/src; rm -rf "$dir"; mkdir -p "$dir"
cp rtl/control/mcs4_system.v rtl/datapath/i4001.v rtl/datapath/i4002.v "$net" "$dir/"
[ $# -eq 0 ] && set -- --nprog 50 --ncyc 1000 --seed 1
exec python3 -I tests/random/c9/run.py --rtl "$dir" --extra "$cells/primitives.v" "$cells/sky130_fd_sc_hd.v" \
  --define FUNCTIONAL UNIT_DELAY= --out build/gl_sky130/out "$@"

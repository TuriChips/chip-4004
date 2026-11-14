#!/usr/bin/env bash
# Leo: generic Yosys synthesis of i4004 alone (the 4001, 4002 and mcs4_system are test fixtures, not synthesized).
# Usage: synth/run.sh   -> synth/report.txt, synth/logs/yosys.log
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
mkdir -p synth/logs
SRC="rtl/top.v $(ls rtl/control/i4004_*.v rtl/datapath/i4004_*.v | tr '\n' ' ')"
yosys -q -l synth/logs/yosys.log -p "
read_verilog $SRC;
hierarchy -check -top i4004;
proc; flatten; opt; memory -nomap; memory_map; opt; techmap; opt;
abc -g AND,NAND,OR,NOR,XOR,XNOR,ANDNOT,ORNOT,MUX; opt_clean -purge;
check -assert;
tee -o synth/report.txt stat;
tee -a synth/report.txt ltp -noff
"
echo "--- warnings ---"; grep -i warning synth/logs/yosys.log | grep -v 'combinational (run' || echo none
grep -E 'Number of cells|\$_' synth/report.txt; grep 'length=' synth/report.txt

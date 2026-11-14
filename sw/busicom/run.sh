#!/usr/bin/env bash
# Homer: Busicom 141-PF acceptance test (spec section 9, test 1). From the repo root: ./sw/busicom/run.sh [keys-file] [expected-file]
# Downloads the firmware at run time (never committed), runs it on mcs4_system with our keyboard/printer model,
# compares the printed lines with the expected file. Log: logs/busicom/run.log. Takes several minutes in Icarus.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
KEYS=${1:-sw/busicom/sums.keys}; EXP=${2:-sw/busicom/sums.expected}
mkdir -p logs/busicom build
./sw/busicom/fetch_rom.sh
# GL=sky130 ./sw/busicom/run.sh runs the same test with synth/sky130/i4004_sky130.v in place of the RTL i4004 (PDK functional
# cell models, zero delay, Icarus). Needs PDK_ROOT (source <toolchain>/scripts/eda-env.sh). Log: logs/busicom/run-gl-sky130.log
LOG=logs/busicom/run.log; EXTRA=""; MODE="rtl"
if [ "${GL:-}" = "sky130" ]; then
  cells="${PDK_ROOT:?GL=sky130 needs PDK_ROOT}/sky130A/libs.ref/sky130_fd_sc_hd/verilog"
  SRC="rtl/control/mcs4_system.v rtl/datapath/i4001.v rtl/datapath/i4002.v synth/sky130/i4004_sky130.v $cells/primitives.v $cells/sky130_fd_sc_hd.v"
  EXTRA="-DFUNCTIONAL -DUNIT_DELAY="; LOG=logs/busicom/run-gl-sky130.log; MODE="gate-level sky130 netlist synth/sky130/i4004_sky130.v"
else
  SRC=$(find rtl -name '*.v' | sort)
fi
iverilog -g2012 $EXTRA -o build/busicom.vvp sw/busicom/busicom_tb.sv $SRC
stamp="main commit: $(git rev-parse HEAD)$(git diff --quiet HEAD -- . ':(exclude)logs' || echo ' (+ uncommitted changes)')"   # computed before the log is (re)written
{ echo "$stamp"; echo "cpu: $MODE"; vvp -n build/busicom.vvp +KEYFILE="$KEYS" | grep -v WARNING; } | tee $LOG
! grep -q '^FAIL' $LOG || { echo "BUSICOM FAIL: harness check failed" | tee -a $LOG; exit 1; }
# printed lines, with trailing blank paper feed removed, as text between the bars
grep '^PRINT' $LOG | sed 's/^PRINT |//; s/|$//; s/^ *//; s/ *$//' | sed '/^$/d' > build/busicom.got
if diff -u "$EXP" build/busicom.got; then echo "BUSICOM PASS: printed lines match $EXP" | tee -a $LOG
else echo "BUSICOM FAIL: printed lines differ from $EXP" | tee -a $LOG; exit 1; fi

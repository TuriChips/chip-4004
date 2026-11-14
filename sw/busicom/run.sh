#!/usr/bin/env bash
# Homer: Busicom 141-PF acceptance test (spec section 9, test 1). From the repo root: ./sw/busicom/run.sh [keys-file] [expected-file]
# Downloads the firmware at run time (never committed), runs it on mcs4_system with our keyboard/printer model,
# compares the printed lines with the expected file. Log: logs/busicom/run.log. Takes several minutes in Icarus.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
KEYS=${1:-sw/busicom/sums.keys}; EXP=${2:-sw/busicom/sums.expected}
mkdir -p logs/busicom build
./sw/busicom/fetch_rom.sh
SRC=$(find rtl -name '*.v' | sort)
iverilog -g2012 -o build/busicom.vvp sw/busicom/busicom_tb.sv $SRC
stamp="main commit: $(git rev-parse HEAD)$(git diff --quiet HEAD -- . ':(exclude)logs' || echo ' (+ uncommitted changes)')"   # computed before the log is (re)written
{ echo "$stamp"; vvp -n build/busicom.vvp +KEYFILE="$KEYS" | grep -v WARNING; } | tee logs/busicom/run.log
! grep -q '^FAIL' logs/busicom/run.log || { echo "BUSICOM FAIL: harness check failed" | tee -a logs/busicom/run.log; exit 1; }
# printed lines, with trailing blank paper feed removed, as text between the bars
grep '^PRINT' logs/busicom/run.log | sed 's/^PRINT |//; s/|$//; s/^ *//; s/ *$//' | sed '/^$/d' > build/busicom.got
if diff -u "$EXP" build/busicom.got; then echo "BUSICOM PASS: printed lines match $EXP" | tee -a logs/busicom/run.log
else echo "BUSICOM FAIL: printed lines differ from $EXP" | tee -a logs/busicom/run.log; exit 1; fi

#!/usr/bin/env bash
# C7: runs reset_mid with the reset landing at 8 consecutive clocks (every period of the cycle, incl. mid 2-word JUN).
set -e
for k in 0 1 2 3 4 5 6 7; do
  EXTRA_PLUS="+RESET_AT=$((400+k))" LOGSUFFIX="_r$((400+k))" tests/run_prog.sh tests/c7/reset_mid | grep -E '^(PASS|FAIL)'
done

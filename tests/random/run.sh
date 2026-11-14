#!/usr/bin/env bash
# Beru's random tests for the 4004, run by the toolchain's `make all` (run_tests.sh).
# A short pass sized for CI; the full C9 run (10,000 x 1,000) is evidence in logs/c9-full-*.
#   1. ref/ref4004.py selftest
#   2. C9: RTL (mcs4_system) vs model, every pin every period, 50 random programs x 1,000 cycles
#   3. Acceptance test 3: model vs MAME mcs40, 5 programs x 2,000 instructions.
#      SKIP (not PASS) when MAME isn't fetched (tests/random/acc3/fetch_mame.sh; CI caches it).
# Usage: tests/random/run.sh   Logs: $RUN_DIR/random-*.log (default logs/<timestamp>/)
set -u
cd "$(git rev-parse --show-toplevel)"
run="${RUN_DIR:-logs/$(date -u +%Y%m%dT%H%M%SZ)}"; mkdir -p "$run"
ok=0
step() { # name log cmd...
  local name=$1 log=$2; shift 2
  if "$@" >"$log" 2>&1 && grep -q '^PASS' "$log" && ! grep -q -E '^(FAIL|MISMATCH)' "$log"; then
    echo "PASS $name"
  else
    echo "FAIL $name ($log)"; ok=1
  fi
}
step ref-selftest "$run/random-ref-selftest.log" python3 -I ref/ref4004.py selftest
step c9 "$run/random-c9.log" python3 -I tests/random/c9/run.py --nprog 50 --ncyc 1000 --seed 1
MAME_DIR="${MAME_DIR:-build/mame}"
if [ -x "$MAME_DIR/root/usr/games/mame" ]; then
  step acc3 "$run/random-acc3.log" env MAME_DIR="$MAME_DIR" python3 -I tests/random/acc3/run.py 5 2000 100
else
  echo "SKIP acc3 (no MAME at $MAME_DIR; run tests/random/acc3/fetch_mame.sh)"
fi
exit $ok

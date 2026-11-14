#!/usr/bin/env bash
# C8 must be able to fail (the 74181's B8 lesson). Applies each mutant to a scratch copy of rtl/ (build/c8/, never
# the tree) and runs tests/c1/acc_group on it: every mutant must make the run FAIL with the expected message.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
ok=0
try() { # name file sed-expr expected-grep
  local d=build/c8/$1; rm -rf "$d"; mkdir -p "$d"; cp -r rtl "$d/"
  sed -i "$3" "$d/rtl/$2"; cmp -s "rtl/$2" "$d/rtl/$2" && { echo "mutant $1: sed changed nothing"; ok=1; return; }
  out=$(RTL_DIR="$d/rtl" tests/run_prog.sh tests/c1/acc_group 2>&1 || true)
  # here-strings, not pipes: with pipefail, grep -q closing early would make echo fail with SIGPIPE
  if grep -q "$4" <<<"$out" && ! grep -q '^PASS' <<<"$out"; then echo "mutant $1: caught ($(grep -m1 "$4" <<<"$out" | cut -c1-70))"
  else echo "mutant $1: NOT caught"; ok=1; fi
}
try dout_z   control/i4004_control.v 's/assign d_out = dout_r;/assign d_out = d_oe ? dout_r : 4'"'"'bzzzz;/' 'FAIL C8'
try cmram_x  control/i4004_control.v 's/? lines : 4'"'"'b0000;/? lines : 4'"'"'bxxxx;/' 'FAIL C8'
try rom_drv  datapath/i4001.v        's/assign d_oe  = drv_m1 | drv_m2 | drv_rdr;/assign d_oe  = 1'"'"'b1;/' 'bus_conflict'
exit $ok

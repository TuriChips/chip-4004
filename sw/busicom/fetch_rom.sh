#!/usr/bin/env bash
# Homer: download the Busicom 141-PF listing from 4004.com and extract the ROM image. Run from the repo root.
# Nothing it writes is committed: everything goes under build/busicom/ (spec section 9, acceptance test 1).
# Credit (must appear in the release): Tim McNerney and Fred Huettig (recovered binaries, with the Computer History Museum),
# Barry Silverman, Brian Silverman and Tim McNerney (disassembly), Lajos Kintli (commented listing). Source: https://www.4004.com/busicom/
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
URL=https://www.4004.com/2009/Busicom-141PF-Calculator_asm_rel-1-0-1.txt
OUT=build/busicom
mkdir -p "$OUT"
curl -fsS --max-time 60 -o "$OUT/listing.txt" "$URL"
# spec section 9: if the listing's terms change from "NonCommercial, ShareAlike, binary not copyrighted", stop and ask Sai.
grep -q 'Noncommercial' "$OUT/listing.txt" && grep -q 'not a copyrighted work' "$OUT/listing.txt" \
  || { echo "listing terms changed or download is not the listing: see spec section 9, ask Sai" >&2; exit 1; }
python3 sw/busicom/extract_rom.py "$OUT/listing.txt" "$OUT/rom"

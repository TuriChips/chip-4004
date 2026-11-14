#!/usr/bin/env python3
"""Pulls the Busicom 141-PF ROM image out of the 4004.com listing, at test time.
Usage: extract_rom.py <listing.txt> <out-dir>   -> <out-dir>/rom0.hex ... romN.hex ($readmemh, 256 lines each)
The listing and the ROM image are never committed (spec section 9, test 1). They live under build/.
Each code line of the listing reads 'AAA bb [bb] label: mnemonic ...' (address, then 1 or 2 hex bytes).
Rows may carry a label first and may hold 1 to 16 bytes; the next row's address says how many, and a gap or overlap stops the script."""
import re, sys, os
row = re.compile(r"^([0-9a-f]{3})\s+(.*)$")
rows = []
for no, ln in enumerate(open(sys.argv[1], errors="replace"), 1):
    m = row.match(ln.rstrip())
    if not m: continue
    toks = m[2].split()
    if toks and re.fullmatch(r"\w+:", toks[0]): toks = toks[1:]     # a label may come before the bytes
    hexes = []
    for t in toks:
        if re.fullmatch(r"[0-9a-f]{2}", t): hexes.append(int(t, 16))
        else: break
    if hexes: rows.append((no, int(m[1], 16), hexes))
img = {}
for i, (no, addr, hexes) in enumerate(rows):
    # the next row's address says how many of the hex-looking words are bytes (the rest is a mnemonic or comment)
    n = rows[i + 1][1] - addr if i + 1 < len(rows) else len(hexes)
    if n < 1 or n > len(hexes): sys.exit("line %d: row at %03x needs %d bytes but shows %d (gap or overlap)" % (no, addr, n, len(hexes)))
    for k in range(n): img[addr + k] = hexes[k]
if not img: sys.exit("no code lines found in " + sys.argv[1])
top = max(img)
os.makedirs(sys.argv[2], exist_ok=True)
for c in range(top // 256 + 1):
    open(os.path.join(sys.argv[2], "rom%d.hex" % c), "w").write("".join("%02x\n" % img.get(c * 256 + i, 0) for i in range(256)))
print("extracted %d bytes, addresses 000-%03x, %d ROM file(s)" % (len(img), top, top // 256 + 1))

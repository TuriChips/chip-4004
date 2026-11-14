#!/usr/bin/env python3
"""Spec section 8 coverage of the C9 generator, model only (no RTL): C5 JCN combinations, C6 DCL codes
on SRC and I/O, C1 carry in/out pairs, KBP inputs. Owner: Beru.
Usage (from the repo root): tests/random/c9/spec_coverage.py NPROG SEED   (same generator and seeds as run.py)
"""
import sys, random, collections, importlib  # noqa: E401
import os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'ref')); sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ref4004 as R
run=importlib.import_module('run')
jcn=set(); dcl_src=set(); dcl_io=set(); cyc=collections.defaultdict(set); kbp=set()
o1, o2 = R.System._exec1, R.System._exec2
def e1(self, w):
    opr, opa = w>>4, w&15
    if opr==2 and opa&1: dcl_src.add(self.ram_bank)
    if opr==0xE: dcl_io.add(self.ram_bank)
    if opr==0xF and opa==0xC: kbp.add(self.acc)
    a0,c0=self.acc,self.cy
    o1(self,w)
    names={0x8:'ADD',0x9:'SUB'}
    if opr in names: cyc[names[opr]].add((c0,self.cy))
    if opr==0xE and opa in (0x8,0xB): cyc['SBM' if opa==8 else 'ADM'].add((c0,self.cy))
    if opr==0xF and opa in (2,8,0xB): cyc[{2:'IAC',8:'DAC',0xB:'DAA'}[opa]].add((c0,self.cy))
def e2(self, w1, B):
    if w1>>4==1: jcn.add((w1&15, int(self.acc==0), int(self.cy), int(self.test_latch)))
    o2(self,w1,B)
R.System._exec1=e1; R.System._exec2=e2
rng=random.Random(int(sys.argv[2]) if len(sys.argv)>2 else 1)
N=int(sys.argv[1])
for p in range(N):
    prog, io_in, tests = run.gen(rng, 1000)
    roms=[R.Rom4001(n, prog[256*n:256*n+256], port_in=bool((run.PORT_IN>>n)&1)) for n in range(16)]
    s=R.System(roms); s.rom_io_in={n:io_in[n] for n in range(16)}; s.do_reset()
    for v in tests:
        t, rst, rp = v&1, (v>>1)&1, (v>>2)&7
        for k in range(8):
            if rst and k==rp: s.do_reset(64); break
            s.step(0,t)
print(f"programs={N}")
print(f"C5 JCN combos: {len(jcn)}/128")
miss=[(c,z,cy,t) for c in range(16) for z in (0,1) for cy in (0,1) for t in (0,1) if (c,z,cy,t) not in jcn]
print("  missing:", miss[:10])
print(f"C6 DCL codes on SRC: {sorted(dcl_src)}  on I/O: {sorted(dcl_io)}")
print("C1 carry in/out pairs:", {k: sorted(v) for k,v in sorted(cyc.items())})
print(f"KBP inputs seen: {len(kbp)}/16")

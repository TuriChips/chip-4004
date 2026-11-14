# C9 full run (spec §8 C9 target: >= 10,000 programs x 1,000 cycles)

- RTL: main 8c91f80. All of rtl/ is on main (#10, #11, #15, #16).
- 20 batches x 500 programs x 1,000 instruction cycles = **10,000 programs, 0 mismatching programs**.
- Every pin, every period (sync, cm_rom, cm_ram, d_oe, d_out where spec §4 compares it, bus,
  bus_conflict), plus the four fixed pins of spec §5 in every period reset is held.
- 6,773 mid-run resets (random cycle and period); every instruction exercised in every batch.
- Seeds: shard 0 = 40000..40009, shard 1 = 50000..50009 (one seed per 500-program batch).
  Reproduce one batch: `tests/random/c9/run.py --nprog 500 --ncyc 1000 --seed 40003`.

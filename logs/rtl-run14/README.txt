tests/c1/dcl_wpm (functional DCL and WPM) on origin/main 692ef50: PASS (38 trace entries).
tb_prog.sv now has one 4002 on each of banks 1-3 (bank 0 unchanged); all 33 programs of c1, c3, c4, c5, acc2 and the 8 c7 runs re-run: PASS.
Mutation checks on rtl/control/i4004_control.v (reverted, not committed):
  line 214  ram_bank <= acc[2:0]  ->  ram_bank <= acc[2:0] & 3'b011 : FAIL at trace[4] (expected 1, got 4)
  line 76   3'b011 lines 4'b0110  ->  4'b0100 (code 3 selects bank 2 only) : FAIL at trace[15] (expected 9, got 2)

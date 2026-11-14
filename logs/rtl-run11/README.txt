After Ada's review on #13 (origin/main 0aacd5f + this branch):
- jcn_acc0..2 (acc==0 term alone, acc in 0,1,2,4,8,15, codes 4-7 and 12-15, cy=0, test=1): PASS. c7/run.sh (8 reset phases): PASS.
- Mutation check on rtl/control/i4004_control.v line 120 (reverted, not committed):
    (acc == 4'd0) -> (acc[0] == 1'b0)     : original 128-case programs 0/8 fail, acc sweep 3/3 fail
    (acc == 4'd0) -> (acc[3:2] == 2'd0)   : original 128-case programs 0/8 fail, acc sweep 3/3 fail
    (acc == 4'd0) -> (acc[2:0] == 3'd0)   : original 128-case programs 0/8 fail, acc sweep 3/3 fail
  So the old C5 alone could not see a partial zero test; the sweep can.

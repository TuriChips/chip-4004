; C7: reset in the middle of a run. State is dirtied (acc, cy, r1, stack depth, inside a 2-word JUN loop),
; then the testbench resets (+RESET_AT). After reset the program must restart at 0x000 with acc = cy = 0
; and (reset held >= 64 edges) r1 = 0, so the same three values are logged a second time.
        nop
        wrr                 ; acc          -> 0
        tcc
        wrr                 ; cy           -> 0
        ld r1
        wrr                 ; r1           -> 0
        ldm 5
        xch r1              ; r1 = 5
        ldm 7
        stc                 ; acc = 7, cy = 1
        jms sub             ; stack depth 1
end:    jun end
sub:    jun sub             ; 2-word instruction spun in place

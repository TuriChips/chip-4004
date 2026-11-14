; C4: BBL right after reset: sp 0 -> 3, pc = slot[3] = 0, so execution restarts at 0x000 (spec 3).
        nop                 ; address 0
        wrr                 ; first pass logs 0, second pass logs 7
        ld r1
        jcn 4, first        ; jump if acc == 0 (first pass only, r1 = 0)
        jun end
first:  ldm 1
        xch r1              ; r1 = 1
        bbl 7               ; back to 0x000 with acc = 7
end:    jun end

; C1, accumulator group F0-FC. After each result: WRR logs acc (expected in acc_group.exp).
; cy is observed by TCC (acc = cy, cy = 0), then WRR.
        nop                 ; first cycle is not compared by the testbench (alignment)
        clb                 ; acc 0, cy 0
        wrr                 ; 0
        stc
        tcc                 ; acc = 1
        wrr                 ; 1
        ldm 9
        iac                 ; 10, cy 0
        wrr                 ; A
        ldm 15
        iac                 ; 0, cy 1
        wrr                 ; 0
        tcc
        wrr                 ; 1
        ldm 5
        cma                 ; 1010
        wrr                 ; A
        clc
        cmc
        tcc
        wrr                 ; 1  (CLC then CMC gives cy 1)
        ldm 10              ; 1010
        clc
        ral                 ; acc 0100, cy 1
        wrr                 ; 4
        tcc
        wrr                 ; 1
        ldm 5               ; 0101
        stc
        rar                 ; acc 1010, cy 1
        wrr                 ; A
        tcc
        wrr                 ; 1
        ldm 0
        dac                 ; F, cy 0 (borrow)
        wrr                 ; F
        tcc
        wrr                 ; 0
        ldm 1
        dac                 ; 0, cy 1
        wrr                 ; 0
        tcc
        wrr                 ; 1
        stc
        tcs                 ; 10, cy 0
        wrr                 ; A
        clc
        tcs                 ; 9
        wrr                 ; 9
        ldm 9
        clc
        daa                 ; unchanged 9, cy 0
        wrr                 ; 9
        ldm 10
        clc
        daa                 ; 16 -> acc 0, cy 1
        wrr                 ; 0
        tcc
        wrr                 ; 1
        ldm 2
        stc
        daa                 ; acc 8, cy stays 1
        wrr                 ; 8
        tcc
        wrr                 ; 1
        ldm 0
        kbp
        wrr                 ; 0
        ldm 1
        kbp
        wrr                 ; 1
        ldm 2
        kbp
        wrr                 ; 2
        ldm 3
        kbp
        wrr                 ; F
        ldm 4
        kbp
        wrr                 ; 3
        ldm 5
        kbp
        wrr                 ; F
        ldm 6
        kbp
        wrr                 ; F
        ldm 7
        kbp
        wrr                 ; F
        ldm 8
        kbp
        wrr                 ; 4
        ldm 9
        kbp
        wrr                 ; F
        ldm 15
        kbp
        wrr                 ; F
end:    jun end

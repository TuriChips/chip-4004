; C1, register ops INC ADD SUB LD XCH LDM (spec 6.1). WRR logs acc, TCC reads cy.
        nop
        clb
        ldm 5
        xch r3              ; r3 = 5, acc = 0 (reset value of r3)
        ld r3
        wrr                 ; 5
        inc r3
        ld r3
        wrr                 ; 6
        ldm 15
        xch r4              ; r4 = 15
        stc
        inc r4              ; r4 = 0, cy unchanged (1)
        ld r4
        wrr                 ; 0
        tcc
        wrr                 ; 1  (INC left cy alone)
        ldm 7
        xch r1              ; r1 = 7
        ldm 9
        clc
        add r1              ; 16 -> acc 0, cy 1
        wrr                 ; 0
        tcc
        wrr                 ; 1
        ldm 3
        stc
        add r1              ; 3+7+1 = 11, cy 0
        wrr                 ; B
        tcc
        wrr                 ; 0
        ldm 9
        clc
        sub r1              ; 9 + ~7(8) + ~0(1) = 18 -> 2, cy 1 (no borrow)
        wrr                 ; 2
        tcc
        wrr                 ; 1
        ldm 5
        clc
        sub r1              ; 5 + 8 + 1 = 14 -> E, cy 0 (borrow)
        wrr                 ; E
        tcc
        wrr                 ; 0
        ldm 9
        stc
        sub r1              ; 9 + 8 + 0 = 17 -> 1, cy 1
        wrr                 ; 1
        tcc
        wrr                 ; 1
        ldm 4
        clc
        sub r6              ; r6 = 0: 4 + 15 + 1 = 20 -> 4, cy 1
        wrr                 ; 4
        tcc
        wrr                 ; 1
        ldm 12
        xch r7              ; r7 = 12, acc = 0
        wrr                 ; 0
        ld r7
        wrr                 ; C
        ldm 3
        xch r7              ; acc = C, r7 = 3
        wrr                 ; C
        ld r7
        wrr                 ; 3
        stc
        ldm 1               ; LDM leaves cy
        xch r7              ; acc = 3, r7 = 1, XCH leaves cy
        wrr                 ; 3
        tcc
        wrr                 ; 1
        ldm 11
        xch r15
        ldm 0
        ld r15
        wrr                 ; B
end:    jun end

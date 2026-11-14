; acc2: manual BCD-to-binary routine, N = 128 (digits char0..2 = [8, 2, 1])
        nop
        fim p7, 0
        src p7
        ldm 8
        wrm
        fim p7, 1
        src p7
        ldm 2
        wrm
        fim p7, 2
        src p7
        ldm 1
        wrm
        jms bcdbin
        ld r2
        wrr
        ld r3
        wrr
end:    jun end
        .org 0x100
bcdbin: fim p0, 0           ; IR(0-1) = 0
        fim p1, 0           ; IR(2-3) = 0
        fim p2, 10          ; IR(4) = 0, IR(5) = 10
        ldm 14
        xch r6              ; IR(6) = 14 (digit counter: two passes)
        src p0              ; RAM address: chip 0, register 0, character 0
        rdm                 ; units digit
        xch r3              ; IR(3) = units
bdgn:   inc r1              ; next character
        src p0
bb1:    rdm                 ; digit
        jcn 4, bb2          ; digit == 0: done with this digit
        dac                 ; digit - 1
        wrm                 ; write it back
        clc
        ld r3
        add r5              ; IR(3) += IR(5)
        xch r3
        ld r2
        add r4              ; IR(2) += IR(4) + carry
        xch r2
        jun bb1
bb2:    fim p2, 100         ; IR(4) = 6, IR(5) = 4
        isz r6, bdgn        ; second pass, then fall through
        bbl 0

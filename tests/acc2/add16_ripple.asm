; acc2: manual Routine A (16-digit decimal addition), A=4999999999999999 B=0000000000000001
        nop
        fim p5, 48
        src p5
        ldm 9
        wrm
        fim p5, 49
        src p5
        ldm 9
        wrm
        fim p5, 50
        src p5
        ldm 9
        wrm
        fim p5, 51
        src p5
        ldm 9
        wrm
        fim p5, 52
        src p5
        ldm 9
        wrm
        fim p5, 53
        src p5
        ldm 9
        wrm
        fim p5, 54
        src p5
        ldm 9
        wrm
        fim p5, 55
        src p5
        ldm 9
        wrm
        fim p5, 56
        src p5
        ldm 9
        wrm
        fim p5, 57
        src p5
        ldm 9
        wrm
        fim p5, 58
        src p5
        ldm 9
        wrm
        fim p5, 59
        src p5
        ldm 9
        wrm
        fim p5, 60
        src p5
        ldm 9
        wrm
        fim p5, 61
        src p5
        ldm 9
        wrm
        fim p5, 62
        src p5
        ldm 9
        wrm
        fim p5, 63
        src p5
        ldm 4
        wrm
        fim p5, 0
        src p5
        ldm 1
        wrm
        fim p5, 1
        src p5
        ldm 0
        wrm
        fim p5, 2
        src p5
        ldm 0
        wrm
        fim p5, 3
        src p5
        ldm 0
        wrm
        fim p5, 4
        src p5
        ldm 0
        wrm
        fim p5, 5
        src p5
        ldm 0
        wrm
        fim p5, 6
        src p5
        ldm 0
        wrm
        fim p5, 7
        src p5
        ldm 0
        wrm
        fim p5, 8
        src p5
        ldm 0
        wrm
        fim p5, 9
        src p5
        ldm 0
        wrm
        fim p5, 10
        src p5
        ldm 0
        wrm
        fim p5, 11
        src p5
        ldm 0
        wrm
        fim p5, 12
        src p5
        ldm 0
        wrm
        fim p5, 13
        src p5
        ldm 0
        wrm
        fim p5, 14
        src p5
        ldm 0
        wrm
        fim p5, 15
        src p5
        ldm 0
        wrm
        jun addiin
        .org 0x100
addiin: fim p0, 0           ; IR(0-1) = 0
        fim p2, 48          ; IR(4) = 3, IR(5) = 0
        ldm 0               ; load 0 to AC
        xch r6              ; exchange AC and IR(6)
        clc                 ; clear carry
ad1:    src p2              ; define RAM address (number A digit)
        rdm                 ; read RAM to AC
        src p0              ; define RAM address (number B digit)
        adm                 ; add RAM to AC, carry enabled
        daa                 ; decimal adjust
        wrm                 ; write AC to RAM
        inc r1              ; increment IR(1)
        inc r5              ; increment IR(5)
        isz r6, ad1         ; 16 digits
overfl: jcn 2, xxx          ; carry out: overflow
        jun next
xxx:    ldm 0
        xch r10
ovfl1:  fim p1, 216
        jms print
        isz r10, ovfl1
        fim p2, 0
        jms clrram
        jun next
        .org 0x200
next:   ldm 7
        wrr
end:    jun end
        .org 0x22C
clrram: ldm 14
        wrr
        bbl 0
        .org 0x25E
print:  ldm 15
        wrr
        bbl 0

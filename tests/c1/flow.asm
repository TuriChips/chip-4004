; C1, control flow and pair ops: ISZ loop, JUN, FIN (same page), FIN P0 overwriting its own address,
; FIM into the last pair, JIN. WRR logs.
        nop
        ldm 13
        xch r2              ; r2 = 13, acc = 0
loop:   iac
        isz r2, loop        ; r2 13->14->15->0: 3 passes, acc = 3
        wrr                 ; 3
        ld r2
        wrr                 ; 0
        jun j1
        ldm 1               ; skipped
        wrr
j1:     ldm 8
        wrr                 ; 8
        fim p0, 0x80
        fin p1              ; p1 = rom[0x80] = 0x5C
        ld r2
        wrr                 ; 5
        ld r3
        wrr                 ; C
        fim p0, 0x90
        fin p0              ; p0 = rom[0x90] = 0x3E (P0 overwrites the address it used)
        ld r0
        wrr                 ; 3
        ld r1
        wrr                 ; E
        fim p7, 0xBD
        ld r14
        wrr                 ; B
        ld r15
        wrr                 ; D
        fim p2, 0xA0
        jin p2              ; jump to 0x0A0 in this page
        ldm 1               ; skipped
        wrr
        .org 0x80
        .byte 0x5C
        .org 0x90
        .byte 0x3E
        .org 0xA0
        ldm 9
        wrr                 ; 9
end:    jun end

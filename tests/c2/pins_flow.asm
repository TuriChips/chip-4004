; C2: pin timing for JUN, JMS, BBL, FIN (second cycle, incl. FIN at xFF: page x+1) and JIN.
        nop
        fim p0, 0x40
        jms sub1
        ldm 2
        jun far
sub1:   nop
        bbl 5
        .org 0x2F0
far:    fim p0, 0x44
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        .org 0x2FF
        fin p1              ; second cycle fetches {page 3, P0 = 0x44}
        .org 0x344
        .byte 0x77
        .org 0x300
        fim p2, 0x70
        jin p2              ; next instruction is at 0x303: page 3, so jumps to 0x370
        .org 0x370
        ldm 4
end:    jun end

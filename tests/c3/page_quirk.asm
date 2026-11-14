; C3: page quirk (spec 6.2). Each instruction sits at the last word(s) of a page; the jump or fetch
; must use page x+1. A bug lands on the page-x marker (logs 1); correct code logs 2 (or A,B for FIN).
        nop
        jun 0x0FE
; T1: JCN (always jumps, code 8) at 0x0FE, second word at 0x0FF -> page 1, offset 0x40
        .org 0x0FE
        jcn 8, 0x40
        ldm 3               ; 0x100: not-taken path (JCN broken)
        wrr
        jun end
        .org 0x040
        ldm 1               ; bug: page 0
        wrr
        jun end
        .org 0x140
        ldm 2               ; correct
        wrr
        jun 0x1FE
; T2: ISZ r1 (0 -> 1, nonzero, jumps) at 0x1FE -> page 2, offset 0x50
        .org 0x150
        ldm 1               ; bug: page 1
        wrr
        jun end
        .org 0x1FE
        isz r1, 0x50
        ldm 3               ; 0x200: not-taken path
        wrr
        jun end
        .org 0x250
        ldm 2               ; correct
        wrr
        jun 0x2F8
; T3: FIN P1 at 0x2FF with P0 = 0x60: byte comes from page 3 (0xAB), not page 2 (0xCD)
        .org 0x260
        .byte 0xCD
        .org 0x2F8
        fim p0, 0x60
        .org 0x2FF
        fin p1
        ld r2               ; 0x300
        wrr                 ; A
        ld r3
        wrr                 ; B
        jun 0x3F8
        .org 0x360
        .byte 0xAB
; T4: JIN P2 at 0x3FF with P2 = 0x70: jumps to page 4, 0x470 (not 0x370)
        .org 0x370
        ldm 1               ; bug: page 3
        wrr
        jun end
        .org 0x3F8
        fim p2, 0x70
        .org 0x3FF
        jin p2
        .org 0x470
        ldm 2               ; correct
        wrr
        jun end
        .org 0x500
end:    jun end

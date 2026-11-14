; C2: pin timing for the one-word register and accumulator instructions, JCN (taken, not taken,
; always, at xFE: page x+1) and ISZ (loop of 3 passes). No I/O: X1-X3 must be quiet for all of them.
        nop
        fim p0, 0x35        ; r0 = 3, r1 = 5
        ldm 7
        inc r1
        add r1
        sub r0
        ld r1
        xch r0
        clc
        stc
        cmc
        cma
        iac
        ral
        rar
        tcc
        dac
        tcs
        daa
        kbp
        clb
        stc
        jcn 4, t1           ; acc == 0: taken
        ldm 9               ; skipped
t1:     jcn 10, t2          ; C = 1010: cy==1 inverted -> not taken
        nop
t2:     jcn 8, t3           ; always taken
        ldm 9               ; skipped
t3:     fim p2, 0xFD        ; r4 = 15, r5 = 13
loop:   isz r5, loop        ; 13 -> 14 -> 15 -> 0: taken twice, then falls through
        jun 0x0FE
        .org 0x0FE
        jcn 8, 0x40         ; second word at 0xFF: jumps to page 1, 0x140
        .org 0x140
        ldm 1
end:    jun end

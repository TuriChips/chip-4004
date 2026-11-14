; C2: pin timing for NOP, LDM, CLB, FIM (2 cycles), SRC, and every I/O-group instruction (bank 0).
        nop
        ldm 5
        clb
        fim p1, 0xA5
        src p1
        ldm 9
        wrm
        wmp
        wrr
        wpm
        wr0
        wr1
        wr2
        wr3
        rdm
        rdr
        adm
        sbm
        rd0
        rd1
        rd2
        rd3
        ldm 3
        fim p3, 0x5C
        src p3
        nop
end:    jun end

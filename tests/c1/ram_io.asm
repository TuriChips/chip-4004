; C1, RAM and I/O group on bank 0 (spec 6.3): SRC, WRM RDM ADM SBM, WR0-3 RD0-3, WMP, WRR RDR.
; SRC address = chip[7:6] reg[5:4] char[3:0]. Every I/O write (WRM, WMP, WRR, WRn) also logs acc.
        nop
        fim p0, 0x35        ; chip 0, reg 3, char 5
        src p0
        ldm 7
        wrm                 ; 7
        ldm 0
        rdm
        wrr                 ; 7
        fim p0, 0x36        ; other character
        src p0
        rdm
        wrr                 ; 0 (RAM is 0 after reset, spec 7)
        fim p0, 0x35
        src p0
        rdm
        wrr                 ; 7
        fim p0, 0x75        ; chip 1, same reg/char
        src p0
        rdm
        wrr                 ; 0
        ldm 9
        wrm                 ; 9
        rdm
        wrr                 ; 9
        fim p0, 0x35        ; back to chip 0: still 7
        src p0
        rdm
        wrr                 ; 7
        ldm 5
        clc
        adm                 ; 5+7+0 = C
        wrr                 ; C
        ldm 9
        clc
        adm                 ; 16 -> 0, cy 1
        wrr                 ; 0
        tcc
        wrr                 ; 1
        ldm 9
        clc
        sbm                 ; 9 + ~7 + 1 = 18 -> 2, cy 1
        wrr                 ; 2
        tcc
        wrr                 ; 1
        ldm 5
        stc
        adm                 ; 5+7+1 = D
        wrr                 ; D
        ldm 9
        stc
        sbm                 ; 9 + 8 + 0 = 17 -> 1, cy 1
        wrr                 ; 1
        tcc
        wrr                 ; 1
        ldm 1
        wr0                 ; 1
        ldm 2
        wr1                 ; 2
        ldm 3
        wr2                 ; 3
        ldm 4
        wr3                 ; 4
        clb
        rd0
        wrr                 ; 1
        rd1
        wrr                 ; 2
        rd2
        wrr                 ; 3
        rd3
        wrr                 ; 4
        rdm
        wrr                 ; 7 (status does not alias data)
        ldm 6
        wmp                 ; 6
        fim p0, 0x25        ; reg 2, char 5
        src p0
        rdm
        wrr                 ; 0
        rd0
        wrr                 ; 0 (status of reg 2 is separate)
        ldm 3
        wrr                 ; 3 (ROM port)
        ldm 5
        rdr
        wrr                 ; 0 (output-configured port reads 0, spec 7)
end:    jun end

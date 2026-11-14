; C6: DCL with all 8 bank codes; each is followed by SRC, a RAM read (M2 and X2 lines) and a write (X2).
        nop
        ldm 0
        dcl
        fim p0, 0x00
        src p0
        rdm
        ldm 0
        wrm
        ldm 1
        dcl
        fim p0, 0x11
        src p0
        rdm
        ldm 1
        wrm
        ldm 2
        dcl
        fim p0, 0x22
        src p0
        rdm
        ldm 2
        wrm
        ldm 3
        dcl
        fim p0, 0x33
        src p0
        rdm
        ldm 3
        wrm
        ldm 4
        dcl
        fim p0, 0x44
        src p0
        rdm
        ldm 4
        wrm
        ldm 5
        dcl
        fim p0, 0x55
        src p0
        rdm
        ldm 5
        wrm
        ldm 6
        dcl
        fim p0, 0x66
        src p0
        rdm
        ldm 6
        wrm
        ldm 7
        dcl
        fim p0, 0x77
        src p0
        rdm
        ldm 7
        wrm
end:    jun end

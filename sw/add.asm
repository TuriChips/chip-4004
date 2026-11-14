; Demo: add two 4-digit decimal numbers on the 4004 and print the sum, one digit at a time,
; on the ROM I/O port of 4001 number 0 (WRR). Digits are written least significant first.
;   1294 + 5678 = 6972   ->  port sees 2, 7, 9, 6 then carry 0
; Digit 0 gets its carry from DAA (4+8=12), digit 1 from ADD itself (9+7+1=17), so both paths run.
; Numbers sit in index registers, least significant digit first: A in r0-r3, B in r4-r7.
        FIM P0, 0x49      ; r0=4 r1=9
        FIM P1, 0x21      ; r2=2 r3=1       A = 1294
        FIM P2, 0x87      ; r4=8 r5=7
        FIM P3, 0x65      ; r6=6 r7=5       B = 5678
        FIM P7, 0x00      ; r14=r15=0: SRC P7 selects 4001 number 0
        CLB               ; carry = 0
        LD 0              ; digit 0
        ADD 4
        DAA               ; decimal adjust, carry carries on to the next digit
        XCH 8
        LD 1
        ADD 5
        DAA
        XCH 9
        LD 2
        ADD 6
        DAA
        XCH 10
        LD 3
        ADD 7
        DAA
        XCH 11
        TCC               ; final carry into r12 (0 or 1)
        XCH 12
        SRC P7
        LD 8
        WRR
        LD 9
        WRR
        LD 10
        WRR
        LD 11
        WRR
        LD 12
        WRR
done:   JUN done          ; halt

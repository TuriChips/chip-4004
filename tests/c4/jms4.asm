; C4: JMS x4 then BBL x4 from sp = 0 (spec 3). The 4th JMS overwrites slot 0 (r1 lost), so the
; 4th BBL lands at the address after the BBL that left subroutine 4 (label after4), not at r1.
        nop
        jms sub1
r1:     ldm 14              ; wrong path: 4th BBL returned to r1
        wrr                 ; E
        jun end
sub1:   jms sub2
r2:     wrr                 ; acc = 2 (BBL 2 from r3 site)
        bbl 1
sub2:   jms sub3
r3:     wrr                 ; acc = 3
        bbl 2
sub3:   jms sub4
r4:     wrr                 ; acc = 4
        bbl 3
sub4:   ldm 8
        wrr                 ; 8
        bbl 4
after4: wrr                 ; acc = 1 (4th BBL)
        jun end
end:    jun end

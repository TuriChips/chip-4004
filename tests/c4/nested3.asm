; C4: 3 nested JMS, 3 BBL, all return correctly (spec 3). WRR logs acc.
        nop
        jms s1
        wrr                 ; acc = 1 from s1's BBL
        jun end
s1:     jms s2
        wrr                 ; acc = 2
        bbl 1
s2:     jms s3
        wrr                 ; acc = 3
        bbl 2
s3:     ldm 9
        wrr                 ; 9
        bbl 3
end:    jun end

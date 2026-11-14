// C9 co-simulation testbench (Beru). Runs NPROG random programs on mcs4_system and dumps every
// pin of every clock period (spec section 4) for tests/random/c9/run.py to compare with ref/ref4004.py.
// Build: 16 x 4001 (chip n = page n, ROM_PORT_IN = `PORT_IN), 4 x 4002 on bank `RAM_BANK (default 0; one bank only, spec 7 C9 rule).
// Files in +dir=<d>: prog<p>/rom<n>.hex (256 bytes each), prog<p>/stim.hex
//   (line 0: rom_io_in, 64-bit hex; lines 1..NCYC per instruction cycle: bit 0 = TEST,
//    bit 1 = reset during this cycle, bits 4:2 = the period at which reset is raised).
// Output <d>/prog<p>/pins.txt: one line per period after reset:
//   sync cm_rom cm_ram d_oe d_out bus conflict   (d_out printed in binary so X/Z shows)
`ifndef RAM_BANK
`define RAM_BANK 0
`endif
`ifndef PORT_IN
`define PORT_IN 16'hF0F0
`endif
module tb;
    reg clk = 0, reset = 1, test = 0;
    reg  [63:0] rom_io_in = 0;
    wire [63:0] rom_io_out, ram_port_out;
    wire [3:0]  bus;
    wire        bus_conflict;
    mcs4_system #(.N_ROM(16), .ROM_PORT_IN(`PORT_IN), .N_RAM_BANK0(`RAM_BANK == 0 ? 4 : 0),
                  .N_RAM_BANK1(`RAM_BANK == 1 ? 4 : 0), .N_RAM_BANK2(`RAM_BANK == 2 ? 4 : 0),
                  .N_RAM_BANK3(`RAM_BANK == 3 ? 4 : 0)) dut (
        .clk(clk), .reset(reset), .test(test), .rom_io_in(rom_io_in),
        .rom_io_out(rom_io_out), .ram_port_out(ram_port_out), .bus(bus), .bus_conflict(bus_conflict));

    reg [63:0] stim [0:4096];
    string dir, pdir;
    integer nprog, ncyc, p, c, k, fd;
    initial begin
        if (!$value$plusargs("dir=%s", dir)) $fatal(1, "need +dir=");
        if (!$value$plusargs("nprog=%d", nprog)) $fatal(1, "need +nprog=");
        if (!$value$plusargs("ncyc=%d", ncyc)) $fatal(1, "need +ncyc=");
        for (p = 0; p < nprog; p = p + 1) begin
            pdir = $sformatf("%s/prog%0d", dir, p);
            begin : load
                string dir;
                dir = pdir;
            $readmemh($sformatf("%s/rom0.hex", dir), dut.g_rom0.u.rom);
            $readmemh($sformatf("%s/rom1.hex", dir), dut.g_rom1.u.rom);
            $readmemh($sformatf("%s/rom2.hex", dir), dut.g_rom2.u.rom);
            $readmemh($sformatf("%s/rom3.hex", dir), dut.g_rom3.u.rom);
            $readmemh($sformatf("%s/rom4.hex", dir), dut.g_rom4.u.rom);
            $readmemh($sformatf("%s/rom5.hex", dir), dut.g_rom5.u.rom);
            $readmemh($sformatf("%s/rom6.hex", dir), dut.g_rom6.u.rom);
            $readmemh($sformatf("%s/rom7.hex", dir), dut.g_rom7.u.rom);
            $readmemh($sformatf("%s/rom8.hex", dir), dut.g_rom8.u.rom);
            $readmemh($sformatf("%s/rom9.hex", dir), dut.g_rom9.u.rom);
            $readmemh($sformatf("%s/rom10.hex", dir), dut.g_rom10.u.rom);
            $readmemh($sformatf("%s/rom11.hex", dir), dut.g_rom11.u.rom);
            $readmemh($sformatf("%s/rom12.hex", dir), dut.g_rom12.u.rom);
            $readmemh($sformatf("%s/rom13.hex", dir), dut.g_rom13.u.rom);
            $readmemh($sformatf("%s/rom14.hex", dir), dut.g_rom14.u.rom);
            $readmemh($sformatf("%s/rom15.hex", dir), dut.g_rom15.u.rom);
            end
            $readmemh({pdir, "/stim.hex"}, stim, 0, ncyc);
            rom_io_in = stim[0];
            reset = 1; test = 0;
            repeat (64) begin #5 clk = 1; #5 clk = 0; end
            reset = 0;
            fd = $fopen({pdir, "/pins.txt"}, "w");
            for (c = 0; c < ncyc; c = c + 1) begin
                test = stim[c + 1][0];
                for (k = 0; k < 8; k = k + 1) begin
                    #4;   // outputs settled for this period
                    if (stim[c + 1][1] && k == stim[c + 1][4:2]) begin
                        // mid-run reset at period k of this cycle: hold 64 edges (spec 5), not dumped;
                        // the next cycle starts at A1 (spec 4)
                        reset = 1;
                        #1 clk = 1; #5 clk = 0;
                        repeat (63) begin #4; #1 clk = 1; #5 clk = 0; end
                        reset = 0;         // at a falling edge, half a period from any rising edge
                        k = 8;             // leave this cycle; the next one starts at A1
                    end else begin
                        $fdisplay(fd, "%b %b %b %b %b %b %b", dut.cpu_sync, dut.cpu_cm_rom, dut.cpu_cm_ram,
                                  dut.cpu_d_oe, dut.cpu_d_out, bus, bus_conflict);
                        #1 clk = 1; #5 clk = 0;
                    end
                end
            end
            $fclose(fd);
        end
        $display("DONE c9 tb: %0d programs x %0d cycles", nprog, ncyc);
        $finish;
    end
endmodule

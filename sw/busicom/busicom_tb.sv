// Busicom 141-PF acceptance harness (Homer): runs the downloaded firmware on mcs4_system with a behavioural
// model of the keyboard matrix, the printer drum and the i4003 shift registers (hardware description: chapter 3
// of the 4004.com listing). It types a key sequence and prints every line the printer prints as "PRINT <text>".
// Plusargs: +KEYS=<hex scan codes, e.g. 9b95 8e ...> are given as a file of one hex code per line via +KEYFILE=<file>
//           +SECT=<clocks per drum sector, default 20800>  +HOLD=<sectors a key is held, default 3>  +MAXCLK=<default: (2*HOLD*keys + 120) sectors>
// Assumptions I made from the listing text, not from a datasheet, that the first run must confirm:
//   - ROM1 and ROM2 ports are active-high; TEST = 1 while the sector signal is active.
//   - Confirmed by the first traced run: the firmware fills the keyboard shifter with 1s and walks a single 0 through it,
//     so the SELECTED column is the one whose shifter bit is 0.
//   - Row under the hammers = pulses since the pulse after which the index signal was seen, mod 13.
`timescale 1ns/1ps
module busicom_tb;
    reg clk = 0, reset = 1, test = 0;
    reg  [63:0] rom_io_in = 64'd0;
    wire [63:0] rom_io_out, ram_port_out;
    wire [3:0]  bus;
    wire        bus_conflict;
    always #5 clk = ~clk;

    mcs4_system #(
        .N_ROM(5),
        .ROM_FILE0("build/busicom/rom/rom0.hex"), .ROM_FILE1("build/busicom/rom/rom1.hex"),
        .ROM_FILE2("build/busicom/rom/rom2.hex"), .ROM_FILE3("build/busicom/rom/rom3.hex"),
        .ROM_FILE4("build/busicom/rom/rom4.hex"),
        .ROM_PORT_IN(16'h0006),                       // 4001 #1 (keyboard rows) and #2 (index, paper button) are inputs
        .N_RAM_BANK0(2), .N_RAM_BANK1(0), .N_RAM_BANK2(0), .N_RAM_BANK3(0)
    ) dut (.clk(clk), .reset(reset), .test(test), .rom_io_in(rom_io_in), .rom_io_out(rom_io_out),
           .ram_port_out(ram_port_out), .bus(bus), .bus_conflict(bus_conflict));

    wire [3:0] p_rom0 = rom_io_out[3:0];
    wire [3:0] p_ram0 = ram_port_out[3:0];

    // ---- keys: scan code = 0x81 + column*4 + row (listing section 3.2) ----
    // 28 ms drum sector / 10.8 us instruction cycle = 2593 cycles = 20744 clocks. 20800 is a multiple of 8 (one cycle), so
    // 'test' and the sector pulse (sect/10 = 2080) change on cycle boundaries.
    integer sect = 20800, hold = 3, maxclk = -1;   // maxclk -1: enough sectors for all keys, see below
    integer keys [0:255]; integer nkeys = 0;
    integer cur_key = -1;                     // scan code held down, -1 = none
    reg [3:0] colrows [0:9];                  // rows pulled high by the pressed key, per shifter bit
    integer c;
    task set_key(input integer code);
        begin
            for (c = 0; c < 10; c = c + 1) colrows[c] = 4'd0;
            if (code >= 0) colrows[(code - 8'h81) / 4] = 4'd1 << ((code - 8'h81) % 4);
            colrows[8] = 4'd0;                // digit point switch: position 0 (no decimals)
            colrows[9] = 4'd0;                // rounding switch: floating
        end
    endtask

    // ---- i4003 keyboard shifter: clock = ROM0 bit0, data = ROM0 bit1; data enters at bit 0 ----
    reg [9:0] kb = 10'd0; reg kb_clk_q = 0;
    reg [3:0] rows;
    integer i;
    always @(*) begin
        rows = 4'd0;
        for (i = 0; i < 10; i = i + 1) if (!kb[i]) rows = rows | colrows[i];
        rom_io_in[7:4] = rows;
    end
    always @(posedge clk) begin
        kb_clk_q <= p_rom0[0];
        if (p_rom0[0] && !kb_clk_q) kb <= {kb[8:0], p_rom0[1]};
    end

    reg [3:0] p0q = 0; reg [3:0] r0q = 0; reg trace = 0;   // +TRACE prints every change of the ROM0 and RAM0 ports
    always @(posedge clk) begin
        p0q <= p_rom0; r0q <= p_ram0;
        if (p_rom0 !== p0q && trace) begin $display("T %0d rom0 port %b kb=%b rows=%b", t, p_rom0, kb, rows); end
        if (p_ram0 !== r0q && trace) begin $display("T %0d ram0 port %b", t, p_ram0); end
    end
    // ---- printer shifter (20 bit, clock = ROM0 bit2, data = ROM0 bit1) and drum ----
    reg [19:0] ps = 20'd0; reg ps_clk_q = 0;
    always @(posedge clk) begin
        ps_clk_q <= p_rom0[2];
        if (p_rom0[2] && !ps_clk_q) ps <= {ps[18:0], p_rom0[1]};
    end
    reg [7:0] line [0:17];                    // columns 1-15, 17, 18 -> indexes 0-14, 15, 16
    integer row = 0, npulse = 0, k, col;
    function [7:0] digit_char(input integer r);
        digit_char = (r <= 9) ? 8'h30 + r : (r == 10 || r == 11) ? 8'h2e : 8'h2d;
    endfunction
    function [7:0] sp17(input integer r);     // column 17 specials (listing 3.3): 0 '#' of col 18 is separate
        case (r) 0: sp17 = "o"; 1: sp17 = "+"; 2: sp17 = "-"; 3: sp17 = "X"; 4: sp17 = "/"; 5: sp17 = "P"; 6: sp17 = "Q";
                 7: sp17 = "^"; 8: sp17 = "="; 9: sp17 = "S"; 10: sp17 = "%"; 11: sp17 = "C"; default: sp17 = "R"; endcase
    endfunction
    function [7:0] sp18(input integer r);
        case (r) 0: sp18 = "#"; 1: sp18 = "*"; 2: sp18 = "I"; 3: sp18 = "J"; 4: sp18 = "K"; 5: sp18 = "P"; 6: sp18 = "Q";
                 7: sp18 = "T"; 8: sp18 = "k"; 9: sp18 = "E"; 10: sp18 = "x"; 11: sp18 = "C"; default: sp18 = "M"; endcase
    endfunction
    reg fire_q = 0, adv_q = 0;
    string s;
    always @(posedge clk) begin
        fire_q <= p_ram0[1]; adv_q <= p_ram0[3];
        if (p_ram0[1] && !fire_q) begin       // hammers: bit0 col 17, bit1 col 18, bits 3..17 columns 1..15
            if (ps[0]) line[15] = sp17(row);
            if (ps[1]) line[16] = sp18(row);
            for (col = 0; col < 15; col = col + 1) if (ps[3 + col]) line[col] = digit_char(row);
        end
        if (p_ram0[3] && !adv_q) begin        // paper advance prints the line
            s = "";
            for (k = 0; k < 17; k = k + 1) s = {s, (line[k] == 0) ? " " : string'(line[k])};
            $display("PRINT |%s|", s);
            for (k = 0; k < 17; k = k + 1) line[k] = 8'd0;
        end
    end

    // ---- drum sector signal on TEST, index on ROM2 bit 0, key schedule ----
    integer t = 0, key_i = 0, held = 0;
    reg test_q = 0;
    always @(posedge clk) test_q <= test;
    wire test_next = (t % sect) < (sect / 10);   // see the sector-period note near 'sect'
    initial begin
        string kf;
        for (k = 0; k < 17; k = k + 1) line[k] = 8'd0;
        trace = $test$plusargs("TRACE"); void'($value$plusargs("SECT=%d", sect)); void'($value$plusargs("HOLD=%d", hold)); void'($value$plusargs("MAXCLK=%d", maxclk));
        if ($value$plusargs("KEYFILE=%s", kf)) $readmemh(kf, keys); // codes; 0 ends the list
        while (keys[nkeys] !== 8'hxx && nkeys < 255 && keys[nkeys] != 0) nkeys = nkeys + 1;
        set_key(-1);
        if (maxclk < 0) maxclk = (2 * hold * nkeys + 120) * sect;
        repeat (80) @(posedge clk);
        reset = 0;
    end
    always @(posedge clk) if (!reset) begin
        t <= t + 1;
        if (dut.cpu.period === 3'd7) test <= test_next;         // change only on the edge that starts A1; sector pulse = first tenth of each period
        // spec section 4 (TEST decision): test may change only on the edge that starts A1, seen one edge later, so the period counter must read A1 (0)
        if (test !== test_q && dut.cpu.period !== 3'd0) begin $display("FAIL TEST changed outside A1 at clock %0d", t); $finish; end
        rom_io_in[8] <= (npulse % 13 == 12) && ((t % sect) < (sect / 10 + 400));   // index, around the 13th pulse
        if (t % sect == sect / 10) row <= (npulse + 1) % 13;   // the drum row advances when the sector pulse ends
        if (t % sect == 0) begin
            npulse <= npulse + 1;
            // key schedule: hold a key for 'hold' pulses, then release for 'hold' pulses
            held <= held + 1;
            if (held == hold) begin set_key(-1); end
            if (held == 2 * hold) begin held <= 0; if (key_i < nkeys) begin set_key(keys[key_i]); key_i <= key_i + 1; end end
        end
        if (bus_conflict) begin $display("FAIL bus_conflict at clock %0d", t); $finish; end
        if (t >= maxclk) begin $display("done after %0d clocks, %0d pulses", t, npulse); $finish; end
    end
endmodule

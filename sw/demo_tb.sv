// Demo testbench (Homer): runs a program on mcs4_system and prints every change of 4001 #0's output port.
// +ROM=<hex file>  +MAXCLK=<clocks to run, default 4000>. The program is expected to end in a jump-to-self.
`timescale 1ns/1ps
module demo_tb;
    reg clk = 0, reset = 1;
    wire [63:0] rom_io_out, ram_port_out;
    wire [3:0]  bus;
    wire        bus_conflict;
    string      rom;
    integer     maxclk, n, last_valid;
    reg [3:0]   last;

    mcs4_system #(.N_ROM(1), .ROM_FILE0("build/demo.hex")) dut (
        .clk(clk), .reset(reset), .test(1'b1), .rom_io_in(64'd0),
        .rom_io_out(rom_io_out), .ram_port_out(ram_port_out), .bus(bus), .bus_conflict(bus_conflict));

    always #5 clk = ~clk;

    initial begin
        if (!$value$plusargs("MAXCLK=%d", maxclk)) maxclk = 4000;
        last = 4'd0;
        repeat (80) @(posedge clk);          // spec 5: reset held 64 clocks or more clears the registers
        reset = 0;
        for (n = 0; n < maxclk; n = n + 1) begin
            @(posedge clk);
            if (bus_conflict) begin $display("FAIL bus_conflict at clock %0d", n); $finish; end
            if (rom_io_out[3:0] !== last) begin
                last = rom_io_out[3:0];
                $display("port %0d", last);
            end
        end
        $display("done after %0d clocks", maxclk);
        $finish;
    end
endmodule

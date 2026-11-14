// Pin-timing testbench (C2, C6): compares every clock period's d_oe, d_out (where the spec compares it),
// sync, cm_rom, cm_ram with an expected file made by tests/c2/pin_gen.py from spec section 4.
// Plusargs: +N=<number of periods> +EXP=<file, one 12-bit hex word per period: {0,sync,d_oe,cm_rom} cm_ram d_out ('x' = not compared)>
// Alignment: the first sync=1 is X3 of cycle 1; the expected file starts at the next clock (A1 of cycle 2).
`timescale 1ns/1ps
module tb_pins;
  reg clk = 0, reset = 1, test = 0;
  wire [63:0] rom_io_out, ram_port_out; wire [3:0] bus; wire bus_conflict;
  wire [3:0] d_out, cm_ram; wire d_oe, sync, cm_rom;
  mcs4_system #(.N_ROM(8),
    .ROM_FILE0(`ROM0), .ROM_FILE1(`ROM1), .ROM_FILE2(`ROM2), .ROM_FILE3(`ROM3),
    .ROM_FILE4(`ROM4), .ROM_FILE5(`ROM5), .ROM_FILE6(`ROM6), .ROM_FILE7(`ROM7), .N_RAM_BANK0(4)) dut (
    .clk(clk), .reset(reset), .test(test), .rom_io_in(64'b0),
    .rom_io_out(rom_io_out), .ram_port_out(ram_port_out), .bus(bus), .bus_conflict(bus_conflict));
  assign d_out = dut.cpu.d_out; assign d_oe = dut.cpu.d_oe; assign sync = dut.cpu.sync;
  assign cm_rom = dut.cpu.cm_rom; assign cm_ram = dut.cpu.cm_ram;
  always #5 clk = ~clk;
  reg [11:0] exp [0:4095]; integer n = 0, idx = 0, errors = 0, cyc = 0, i; reg aligned = 0; string expf;
  initial begin
    if (!$value$plusargs("EXP=%s", expf)) begin $display("FAIL no +EXP"); $finish; end
    $readmemh(expf, exp);
    if (!$value$plusargs("N=%d", n)) begin $display("FAIL no +N"); $finish; end
    repeat (70) @(posedge clk); @(negedge clk); reset = 0;
  end
  reg [11:0] e;
  always @(negedge clk) if (!reset) begin
    cyc = cyc + 1;
    if (aligned) begin
      e = exp[idx];
      if ({sync, d_oe, cm_rom, cm_ram} !== {e[10:8], e[7:4]} ||
          (e[3:0] !== 4'bxxxx && d_out !== e[3:0]) || bus_conflict !== 1'b0) begin
        errors = errors + 1;
        $display("FAIL period %0d (cycle %0d, period %0d): expected sync=%b oe=%b rom=%b ram=%h dout=%h, got sync=%b oe=%b rom=%b ram=%h dout=%h conflict=%b",
                 idx, idx/8 + 2, idx % 8, e[10], e[9], e[8], e[7:4], e[3:0], sync, d_oe, cm_rom, cm_ram, d_out, bus_conflict);
      end
      idx = idx + 1;
      if (idx == n) begin $display("%s: periods=%0d errors=%0d", errors ? "FAIL" : "PASS", n, errors); $finish; end
    end else if (sync === 1'b1) aligned = 1;
    if (cyc > 20000) begin $display("FAIL timeout"); $finish; end
  end
endmodule

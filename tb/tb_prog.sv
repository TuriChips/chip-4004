// Program-trace testbench on mcs4_system pins only (spec sections 2, 4, 8 C1/C8).
// Plusargs: +EXP=<expected trace, one hex nibble per line>  +TIMEOUT=<clocks>  +TEST=<0|1, the test pin, default 0>  +RESET_AT=<clock: reset again mid-run, see C7>
// Trace = the value on d_out at X2 of every I/O-write-class instruction (d_oe=1, cm_rom=0 at X2:
// WRM, WMP, WRR, WPM, WR0-3), so a program shows acc/cy/registers by writing them out.
// Also checks, on every clock after the first sync: no X/Z on any output (C8), bus_conflict = 0.
// Alignment: the clock after sync=1 is A1 (spec section 4). The first cycle after reset is not
// compared (programs start with NOP); exact start-after-reset is tested separately (C7).
`timescale 1ns/1ps
module tb_prog;
  reg clk = 0, reset = 1, test = 0;
  wire [63:0] rom_io_out, ram_port_out;
  wire [3:0] bus; wire bus_conflict;
  wire [3:0] d_out; wire d_oe, sync, cm_rom; wire [3:0] cm_ram;
  string rom0, expf; integer timeout; integer tv;
  // 8 4001s (pages 0-7, files from -DROM<n>="path" (Icarus cannot concatenate strings in a parameter)), 4 4002s on bank 0. ROM_FILE<n> per chip (Zura, #16).
  mcs4_system #(.N_ROM(8),
    .ROM_FILE0(`ROM0), .ROM_FILE1(`ROM1), .ROM_FILE2(`ROM2),
    .ROM_FILE3(`ROM3), .ROM_FILE4(`ROM4), .ROM_FILE5(`ROM5),
    .ROM_FILE6(`ROM6), .ROM_FILE7(`ROM7), .N_RAM_BANK0(4)) dut (
    .clk(clk), .reset(reset), .test(test), .rom_io_in(64'b0),
    .rom_io_out(rom_io_out), .ram_port_out(ram_port_out), .bus(bus), .bus_conflict(bus_conflict));
  // pins of the 4004 are observed through the system's hierarchy-free ports where available:
  assign d_out = dut.cpu.d_out; assign d_oe = dut.cpu.d_oe; assign sync = dut.cpu.sync;
  assign cm_rom = dut.cpu.cm_rom; assign cm_ram = dut.cpu.cm_ram;
  always #5 clk = ~clk;

  integer rst_at = -1, rcnt = 0;
  reg [3:0] exp [0:4095]; integer nexp = 0, got = 0, errors = 0, cyc = 0;
  integer per = 0; reg aligned = 0; // per: 0=A1 .. 7=X3 (spec section 4)
  integer i; reg [8*256-1:0] line;
  initial begin
    if (!$value$plusargs("EXP=%s", expf)) begin $display("FAIL no +EXP"); $finish; end
    if (!$value$plusargs("TIMEOUT=%d", timeout)) timeout = 100000;
    if (!$value$plusargs("RESET_AT=%d", rst_at)) rst_at = -1;
    if ($value$plusargs("TEST=%d", tv)) test = tv[0];   // static TEST pin for the whole run
    $readmemh(expf, exp); // count lines
    for (i = 0; i < 4096; i = i + 1) if (^exp[i] !== 1'bx) nexp = i + 1;
    if (nexp == 0) begin $display("FAIL empty or missing +EXP file %0s (no expected trace)", expf); $finish; end
    repeat (70) @(posedge clk);   // reset held >= 64 edges (spec section 5)
    @(negedge clk); reset = 0;
  end
  // sample at the falling edge: the middle of each clock period
  // Optional mid-run reset (C7): +RESET_AT=<clock>  asserts reset there, holds it 70 edges (>= 64, spec section 5),
  // checks the reset pins (spec section 5: d_oe, sync, cm_rom, cm_ram all 0), and after it falls the next clock is A1.
  reg in_mid = 0, mid_done = 0;
  task midreset; begin
    if (!in_mid) begin in_mid = 1; mid_done = 1; reset = 1; rcnt = 0; end
    else begin
      rcnt = rcnt + 1;
      if (rcnt >= 2 && ({d_oe, sync, cm_rom, cm_ram} !== 7'b0)) begin
        errors = errors + 1; $display("FAIL reset pins at reset clock %0d: oe=%b sync=%b rom=%b ram=%h", rcnt, d_oe, sync, cm_rom, cm_ram); end
      if (rcnt == 70) begin reset = 0; in_mid = 0; per = 7; aligned = 1; end
    end
  end endtask
  always @(negedge clk) if (in_mid || (rst_at >= 0 && cyc == rst_at && !mid_done)) midreset;
  else if (!reset) begin
    cyc = cyc + 1;
    if (aligned || sync === 1'b1) begin
      if (^{d_out, d_oe, sync, cm_rom, cm_ram, bus, bus_conflict, rom_io_out, ram_port_out} === 1'bx) begin   // C8: every output, d_out too
        errors = errors + 1; $display("FAIL C8 X/Z on pins at clock %0d (period %0d)", cyc, per);
      end
      if (bus_conflict !== 1'b0) begin errors = errors + 1; $display("FAIL bus_conflict at clock %0d", cyc); end
    end
    if (sync === 1'b1) begin per = 7; aligned = 1; end   // sync=1 is X3 (spec section 4); the next clock is A1
    else if (aligned) per = (per + 1) % 8;
    if (per == 6 && d_oe === 1'b1 && cm_rom === 1'b0) begin // X2 of an I/O write
      if (got < nexp) begin
        if (d_out !== exp[got]) begin errors = errors + 1;
          $display("FAIL trace[%0d]: expected %h got %h (clock %0d)", got, exp[got], d_out, cyc); end
      end else begin errors = errors + 1; $display("FAIL extra write %h at clock %0d", d_out, cyc); end
      got = got + 1;
    end
    if (got == nexp && per == 7) finish_test;
    if (cyc > timeout) begin $display("FAIL timeout: %0d of %0d trace entries", got, nexp); $finish; end
  end
  task finish_test; begin
    $display("%s: trace=%0d expected=%0d errors=%0d", errors ? "FAIL" : "PASS", got, nexp, errors);
    $finish;
  end endtask
endmodule

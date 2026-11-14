// mcs4_system: one 4004, up to 16 4001 ROMs and up to 16 4002 RAMs (spec sections 2 and 7,
// blocks.md section 2). Wiring and bus resolution only.
//
// ROM_FILE0..ROM_FILE15: the $readmemh path of each 4001 (blocks.md says ROM_FILES; iverilog can't
// index a string array parameter, so it is 16 string parameters, ROM_FILE<n> for chip n).
// ROM_PORT_IN: bit n = 1 makes chip n's port an input.
// N_RAM_BANKb (0-4): number of 4002s on CM-RAMb; chip c of bank b has CHIP = c.
// verilator lint_off UNUSEDSIGNAL
module mcs4_system #(
    parameter integer N_ROM        = 1,
    parameter string  ROM_FILE0 = "",
    parameter string  ROM_FILE1 = "",
    parameter string  ROM_FILE2 = "",
    parameter string  ROM_FILE3 = "",
    parameter string  ROM_FILE4 = "",
    parameter string  ROM_FILE5 = "",
    parameter string  ROM_FILE6 = "",
    parameter string  ROM_FILE7 = "",
    parameter string  ROM_FILE8 = "",
    parameter string  ROM_FILE9 = "",
    parameter string  ROM_FILE10 = "",
    parameter string  ROM_FILE11 = "",
    parameter string  ROM_FILE12 = "",
    parameter string  ROM_FILE13 = "",
    parameter string  ROM_FILE14 = "",
    parameter string  ROM_FILE15 = "",
    parameter [15:0]  ROM_PORT_IN  = 16'h0000,
    parameter integer N_RAM_BANK0  = 4,
    parameter integer N_RAM_BANK1  = 0,
    parameter integer N_RAM_BANK2  = 0,
    parameter integer N_RAM_BANK3  = 0
) (
    input  wire          clk,
    input  wire          reset,
    input  wire          test,
    input  wire [63:0]   rom_io_in,
    output wire [63:0]   rom_io_out,
    output wire [63:0]   ram_port_out,
    output wire [3:0]    bus,
    output wire          bus_conflict
);
    wire [3:0] cpu_d_out;
    wire       cpu_d_oe, cpu_sync, cpu_cm_rom;
    wire [3:0] cpu_cm_ram;

    // per-chip driver outputs, unused slots tied to 0
    wire [3:0]  rom_d   [0:15];
    wire [15:0] rom_oe;
    wire [3:0]  ram_d   [0:15];
    wire [15:0] ram_oe;
    wire [3:0]  rom_io  [0:15];
    wire [3:0]  ram_po  [0:15];

    // Resolved bus: the CPU wins when it drives; otherwise the OR of the drivers
    // (one driver in a correct run; with a conflict the value is undefined, bus_conflict flags it).
    reg [3:0] mem_bus;
    integer k;
    always @(*) begin
        mem_bus = 4'd0;
        for (k = 0; k < 16; k = k + 1) begin
            if (rom_oe[k]) mem_bus = mem_bus | rom_d[k];
            if (ram_oe[k]) mem_bus = mem_bus | ram_d[k];
        end
    end
    assign bus = cpu_d_oe ? cpu_d_out : mem_bus;

    // bus_conflict: two or more drivers with d_oe = 1 in this period
    reg [5:0] n_drv;
    integer m;
    always @(*) begin
        n_drv = {5'd0, cpu_d_oe};
        for (m = 0; m < 16; m = m + 1) n_drv = n_drv + {5'd0, rom_oe[m]} + {5'd0, ram_oe[m]};
    end
    assign bus_conflict = (n_drv > 6'd1);

    i4004 cpu (
        .clk(clk), .reset(reset), .test(test), .d_in(bus),
        .d_out(cpu_d_out), .d_oe(cpu_d_oe), .sync(cpu_sync),
        .cm_rom(cpu_cm_rom), .cm_ram(cpu_cm_ram)
    );

    genvar b, c;
    generate
        if (N_ROM > 0) begin : g_rom0
            i4001 #(.CHIP(4'd0), .PORT_IN(ROM_PORT_IN[0]), .ROM_FILE(ROM_FILE0)) u (
                .clk(clk), .reset(reset), .sync(cpu_sync), .cm_rom(cpu_cm_rom), .bus(bus),
                .d_out(rom_d[0]), .d_oe(rom_oe[0]),
                .io_in(rom_io_in[0*4 +: 4]), .io_out(rom_io[0])
            );
        end else begin : g_rom0
            assign rom_d[0]  = 4'd0;
            assign rom_oe[0] = 1'b0;
            assign rom_io[0] = 4'd0;
        end
        assign rom_io_out[0*4 +: 4] = rom_io[0];
        if (N_ROM > 1) begin : g_rom1
            i4001 #(.CHIP(4'd1), .PORT_IN(ROM_PORT_IN[1]), .ROM_FILE(ROM_FILE1)) u (
                .clk(clk), .reset(reset), .sync(cpu_sync), .cm_rom(cpu_cm_rom), .bus(bus),
                .d_out(rom_d[1]), .d_oe(rom_oe[1]),
                .io_in(rom_io_in[1*4 +: 4]), .io_out(rom_io[1])
            );
        end else begin : g_rom1
            assign rom_d[1]  = 4'd0;
            assign rom_oe[1] = 1'b0;
            assign rom_io[1] = 4'd0;
        end
        assign rom_io_out[1*4 +: 4] = rom_io[1];
        if (N_ROM > 2) begin : g_rom2
            i4001 #(.CHIP(4'd2), .PORT_IN(ROM_PORT_IN[2]), .ROM_FILE(ROM_FILE2)) u (
                .clk(clk), .reset(reset), .sync(cpu_sync), .cm_rom(cpu_cm_rom), .bus(bus),
                .d_out(rom_d[2]), .d_oe(rom_oe[2]),
                .io_in(rom_io_in[2*4 +: 4]), .io_out(rom_io[2])
            );
        end else begin : g_rom2
            assign rom_d[2]  = 4'd0;
            assign rom_oe[2] = 1'b0;
            assign rom_io[2] = 4'd0;
        end
        assign rom_io_out[2*4 +: 4] = rom_io[2];
        if (N_ROM > 3) begin : g_rom3
            i4001 #(.CHIP(4'd3), .PORT_IN(ROM_PORT_IN[3]), .ROM_FILE(ROM_FILE3)) u (
                .clk(clk), .reset(reset), .sync(cpu_sync), .cm_rom(cpu_cm_rom), .bus(bus),
                .d_out(rom_d[3]), .d_oe(rom_oe[3]),
                .io_in(rom_io_in[3*4 +: 4]), .io_out(rom_io[3])
            );
        end else begin : g_rom3
            assign rom_d[3]  = 4'd0;
            assign rom_oe[3] = 1'b0;
            assign rom_io[3] = 4'd0;
        end
        assign rom_io_out[3*4 +: 4] = rom_io[3];
        if (N_ROM > 4) begin : g_rom4
            i4001 #(.CHIP(4'd4), .PORT_IN(ROM_PORT_IN[4]), .ROM_FILE(ROM_FILE4)) u (
                .clk(clk), .reset(reset), .sync(cpu_sync), .cm_rom(cpu_cm_rom), .bus(bus),
                .d_out(rom_d[4]), .d_oe(rom_oe[4]),
                .io_in(rom_io_in[4*4 +: 4]), .io_out(rom_io[4])
            );
        end else begin : g_rom4
            assign rom_d[4]  = 4'd0;
            assign rom_oe[4] = 1'b0;
            assign rom_io[4] = 4'd0;
        end
        assign rom_io_out[4*4 +: 4] = rom_io[4];
        if (N_ROM > 5) begin : g_rom5
            i4001 #(.CHIP(4'd5), .PORT_IN(ROM_PORT_IN[5]), .ROM_FILE(ROM_FILE5)) u (
                .clk(clk), .reset(reset), .sync(cpu_sync), .cm_rom(cpu_cm_rom), .bus(bus),
                .d_out(rom_d[5]), .d_oe(rom_oe[5]),
                .io_in(rom_io_in[5*4 +: 4]), .io_out(rom_io[5])
            );
        end else begin : g_rom5
            assign rom_d[5]  = 4'd0;
            assign rom_oe[5] = 1'b0;
            assign rom_io[5] = 4'd0;
        end
        assign rom_io_out[5*4 +: 4] = rom_io[5];
        if (N_ROM > 6) begin : g_rom6
            i4001 #(.CHIP(4'd6), .PORT_IN(ROM_PORT_IN[6]), .ROM_FILE(ROM_FILE6)) u (
                .clk(clk), .reset(reset), .sync(cpu_sync), .cm_rom(cpu_cm_rom), .bus(bus),
                .d_out(rom_d[6]), .d_oe(rom_oe[6]),
                .io_in(rom_io_in[6*4 +: 4]), .io_out(rom_io[6])
            );
        end else begin : g_rom6
            assign rom_d[6]  = 4'd0;
            assign rom_oe[6] = 1'b0;
            assign rom_io[6] = 4'd0;
        end
        assign rom_io_out[6*4 +: 4] = rom_io[6];
        if (N_ROM > 7) begin : g_rom7
            i4001 #(.CHIP(4'd7), .PORT_IN(ROM_PORT_IN[7]), .ROM_FILE(ROM_FILE7)) u (
                .clk(clk), .reset(reset), .sync(cpu_sync), .cm_rom(cpu_cm_rom), .bus(bus),
                .d_out(rom_d[7]), .d_oe(rom_oe[7]),
                .io_in(rom_io_in[7*4 +: 4]), .io_out(rom_io[7])
            );
        end else begin : g_rom7
            assign rom_d[7]  = 4'd0;
            assign rom_oe[7] = 1'b0;
            assign rom_io[7] = 4'd0;
        end
        assign rom_io_out[7*4 +: 4] = rom_io[7];
        if (N_ROM > 8) begin : g_rom8
            i4001 #(.CHIP(4'd8), .PORT_IN(ROM_PORT_IN[8]), .ROM_FILE(ROM_FILE8)) u (
                .clk(clk), .reset(reset), .sync(cpu_sync), .cm_rom(cpu_cm_rom), .bus(bus),
                .d_out(rom_d[8]), .d_oe(rom_oe[8]),
                .io_in(rom_io_in[8*4 +: 4]), .io_out(rom_io[8])
            );
        end else begin : g_rom8
            assign rom_d[8]  = 4'd0;
            assign rom_oe[8] = 1'b0;
            assign rom_io[8] = 4'd0;
        end
        assign rom_io_out[8*4 +: 4] = rom_io[8];
        if (N_ROM > 9) begin : g_rom9
            i4001 #(.CHIP(4'd9), .PORT_IN(ROM_PORT_IN[9]), .ROM_FILE(ROM_FILE9)) u (
                .clk(clk), .reset(reset), .sync(cpu_sync), .cm_rom(cpu_cm_rom), .bus(bus),
                .d_out(rom_d[9]), .d_oe(rom_oe[9]),
                .io_in(rom_io_in[9*4 +: 4]), .io_out(rom_io[9])
            );
        end else begin : g_rom9
            assign rom_d[9]  = 4'd0;
            assign rom_oe[9] = 1'b0;
            assign rom_io[9] = 4'd0;
        end
        assign rom_io_out[9*4 +: 4] = rom_io[9];
        if (N_ROM > 10) begin : g_rom10
            i4001 #(.CHIP(4'd10), .PORT_IN(ROM_PORT_IN[10]), .ROM_FILE(ROM_FILE10)) u (
                .clk(clk), .reset(reset), .sync(cpu_sync), .cm_rom(cpu_cm_rom), .bus(bus),
                .d_out(rom_d[10]), .d_oe(rom_oe[10]),
                .io_in(rom_io_in[10*4 +: 4]), .io_out(rom_io[10])
            );
        end else begin : g_rom10
            assign rom_d[10]  = 4'd0;
            assign rom_oe[10] = 1'b0;
            assign rom_io[10] = 4'd0;
        end
        assign rom_io_out[10*4 +: 4] = rom_io[10];
        if (N_ROM > 11) begin : g_rom11
            i4001 #(.CHIP(4'd11), .PORT_IN(ROM_PORT_IN[11]), .ROM_FILE(ROM_FILE11)) u (
                .clk(clk), .reset(reset), .sync(cpu_sync), .cm_rom(cpu_cm_rom), .bus(bus),
                .d_out(rom_d[11]), .d_oe(rom_oe[11]),
                .io_in(rom_io_in[11*4 +: 4]), .io_out(rom_io[11])
            );
        end else begin : g_rom11
            assign rom_d[11]  = 4'd0;
            assign rom_oe[11] = 1'b0;
            assign rom_io[11] = 4'd0;
        end
        assign rom_io_out[11*4 +: 4] = rom_io[11];
        if (N_ROM > 12) begin : g_rom12
            i4001 #(.CHIP(4'd12), .PORT_IN(ROM_PORT_IN[12]), .ROM_FILE(ROM_FILE12)) u (
                .clk(clk), .reset(reset), .sync(cpu_sync), .cm_rom(cpu_cm_rom), .bus(bus),
                .d_out(rom_d[12]), .d_oe(rom_oe[12]),
                .io_in(rom_io_in[12*4 +: 4]), .io_out(rom_io[12])
            );
        end else begin : g_rom12
            assign rom_d[12]  = 4'd0;
            assign rom_oe[12] = 1'b0;
            assign rom_io[12] = 4'd0;
        end
        assign rom_io_out[12*4 +: 4] = rom_io[12];
        if (N_ROM > 13) begin : g_rom13
            i4001 #(.CHIP(4'd13), .PORT_IN(ROM_PORT_IN[13]), .ROM_FILE(ROM_FILE13)) u (
                .clk(clk), .reset(reset), .sync(cpu_sync), .cm_rom(cpu_cm_rom), .bus(bus),
                .d_out(rom_d[13]), .d_oe(rom_oe[13]),
                .io_in(rom_io_in[13*4 +: 4]), .io_out(rom_io[13])
            );
        end else begin : g_rom13
            assign rom_d[13]  = 4'd0;
            assign rom_oe[13] = 1'b0;
            assign rom_io[13] = 4'd0;
        end
        assign rom_io_out[13*4 +: 4] = rom_io[13];
        if (N_ROM > 14) begin : g_rom14
            i4001 #(.CHIP(4'd14), .PORT_IN(ROM_PORT_IN[14]), .ROM_FILE(ROM_FILE14)) u (
                .clk(clk), .reset(reset), .sync(cpu_sync), .cm_rom(cpu_cm_rom), .bus(bus),
                .d_out(rom_d[14]), .d_oe(rom_oe[14]),
                .io_in(rom_io_in[14*4 +: 4]), .io_out(rom_io[14])
            );
        end else begin : g_rom14
            assign rom_d[14]  = 4'd0;
            assign rom_oe[14] = 1'b0;
            assign rom_io[14] = 4'd0;
        end
        assign rom_io_out[14*4 +: 4] = rom_io[14];
        if (N_ROM > 15) begin : g_rom15
            i4001 #(.CHIP(4'd15), .PORT_IN(ROM_PORT_IN[15]), .ROM_FILE(ROM_FILE15)) u (
                .clk(clk), .reset(reset), .sync(cpu_sync), .cm_rom(cpu_cm_rom), .bus(bus),
                .d_out(rom_d[15]), .d_oe(rom_oe[15]),
                .io_in(rom_io_in[15*4 +: 4]), .io_out(rom_io[15])
            );
        end else begin : g_rom15
            assign rom_d[15]  = 4'd0;
            assign rom_oe[15] = 1'b0;
            assign rom_io[15] = 4'd0;
        end
        assign rom_io_out[15*4 +: 4] = rom_io[15];

        for (b = 0; b < 4; b = b + 1) begin : g_bank
            localparam integer N_RAM = (b == 0) ? N_RAM_BANK0 : (b == 1) ? N_RAM_BANK1 :
                                       (b == 2) ? N_RAM_BANK2 : N_RAM_BANK3;
            for (c = 0; c < 4; c = c + 1) begin : g_ram
                if (c < N_RAM) begin : present
                    i4002 #(.CHIP(c[1:0])) u (
                        .clk(clk), .reset(reset), .sync(cpu_sync), .cm_ram(cpu_cm_ram[b]), .bus(bus),
                        .d_out(ram_d[4*b+c]), .d_oe(ram_oe[4*b+c]), .port_out(ram_po[4*b+c])
                    );
                end else begin : absent
                    assign ram_d[4*b+c]  = 4'd0;
                    assign ram_oe[4*b+c] = 1'b0;
                    assign ram_po[4*b+c] = 4'd0;
                end
                assign ram_port_out[4*(4*b+c) +: 4] = ram_po[4*b+c];
            end
        end
    endgenerate
endmodule
// verilator lint_on UNUSEDSIGNAL

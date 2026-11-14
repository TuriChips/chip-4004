// Ada: MCS-4 RAM, 4 registers x (16 data + 4 status) x 4 bits, plus a 4-bit output port.
// Ports: docs/blocks.md section 2. Behaviour: spec 6.3 and 7 (per-chip SRC model).
module i4002 #(
    parameter [1:0] CHIP = 2'd0
) (
    input  wire       clk,
    input  wire       reset,
    input  wire       sync,
    input  wire       cm_ram,
    input  wire [3:0] bus,
    output wire [3:0] d_out,
    output wire       d_oe,
    output reg  [3:0] port_out
);
    reg [3:0] ram [0:63];  // {register, character}
    reg [3:0] stat [0:15]; // {register, status n}
    reg [2:0] period;      // 0 = A1 ... 7 = X3
    reg [7:0] src;         // this chip's own SRC latch
    reg       src_pend;    // cm_ram was 1 at X2: take the low nibble at X3
    reg       io;          // cm_ram = 1 at M2
    reg [3:0] opa;
    integer i;

    wire       me   = io && (src[7:6] == CHIP);
    wire [1:0] reg_ = src[5:4];
    wire [3:0] rd_c = ram[{reg_, src[3:0]}];
    wire [3:0] rd_s = stat[{reg_, opa[1:0]}];

    // Reads: SBM 8, RDM 9, ADM B drive M; RD0..RD3 (C..F) drive S_n. All at X2.
    wire rd_m = me && period == 3'd6 && (opa == 4'h8 || opa == 4'h9 || opa == 4'hB);
    wire rd_s_en = me && period == 3'd6 && opa[3:2] == 2'b11;

    assign d_oe  = rd_m | rd_s_en;
    assign d_out = rd_m ? rd_c : rd_s_en ? rd_s : 4'h0;

    always @(posedge clk) begin
        if (reset) begin
            period   <= 3'd0;
            src      <= 8'd0;
            src_pend <= 1'b0;
            io       <= 1'b0;
            opa      <= 4'd0;
            port_out <= 4'd0;
            for (i = 0; i < 64; i = i + 1) ram[i]  <= 4'd0;
            for (i = 0; i < 16; i = i + 1) stat[i] <= 4'd0;
        end else begin
            period <= sync ? 3'd0 : period + 3'd1;
            src_pend <= (period == 3'd6) && cm_ram;
            if (period == 3'd4) begin io <= cm_ram; opa <= bus; end
            if (period == 3'd6) begin
                if (cm_ram) src[7:4] <= bus;                         // SRC, high nibble
                else if (me) begin
                    if (opa == 4'h0) ram[{reg_, src[3:0]}] <= bus;   // WRM
                    if (opa == 4'h1) port_out <= bus;                // WMP
                    if (opa[3:2] == 2'b01) stat[{reg_, opa[1:0]}] <= bus; // WR0..WR3
                end
            end
            if (period == 3'd7 && src_pend) src[3:0] <= bus;         // SRC, low nibble
        end
    end
endmodule

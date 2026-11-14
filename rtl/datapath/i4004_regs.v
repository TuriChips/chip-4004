// Ada: the 16 index registers. Ports: docs/blocks.md section 2. Pair p = {r[2p], r[2p+1]}, r[2p] high (spec 3).
module i4004_regs (
    input  wire       clk,
    input  wire       reset,
    input  wire [3:0] sel,
    output wire [3:0] r_data,
    output wire [3:0] r_inc,
    output wire [7:0] p_data,
    input  wire       r_we,
    input  wire [3:0] r_wdata,
    input  wire       p_we,
    input  wire [7:0] p_wdata
);
    reg [3:0] r [0:15];
    integer i;

    assign r_data = r[sel];
    assign r_inc  = r[sel] + 4'd1;
    assign p_data = {r[{sel[3:1], 1'b0}], r[{sel[3:1], 1'b1}]};

    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 16; i = i + 1) r[i] <= 4'd0;
        end else if (r_we) begin
            r[sel] <= r_wdata;
        end else if (p_we) begin
            r[{sel[3:1], 1'b0}] <= p_wdata[7:4];
            r[{sel[3:1], 1'b1}] <= p_wdata[3:0];
        end
    end
endmodule

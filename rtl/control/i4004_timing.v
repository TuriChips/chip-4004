// i4004_timing: clock-period counter (spec section 4, blocks.md section 2).
// period 0 = A1 ... 7 = X3. Reads 0 while reset = 1; sync = 1 exactly in X3.
module i4004_timing (
    input  wire       clk,
    input  wire       reset,
    output wire [2:0] period,
    output wire       sync
);
    reg [2:0] cnt;

    always @(posedge clk) begin
        if (reset) cnt <= 3'd0;
        else       cnt <= cnt + 3'd1;
    end

    assign period = reset ? 3'd0 : cnt;
    assign sync   = (period == 3'd7) & ~reset;
endmodule

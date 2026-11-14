// Ada: acc, cy and every operation that writes them. Ports and op encoding: docs/blocks.md section 2. Behaviour: spec 3, 6.
module i4004_alu (
    input  wire       clk,
    input  wire       reset,
    input  wire       we,
    input  wire [4:0] op,
    input  wire [3:0] b,
    output reg  [3:0] acc,
    output reg        cy
);
    reg [3:0] n_acc;
    reg       n_cy;
    reg [4:0] t;

    always @* begin
        n_acc = acc;
        n_cy  = cy;
        t     = 5'd0;
        if (op[4]) begin
            case (op[3:0])
                4'h0: begin n_acc = 4'd0; n_cy = 1'b0; end                      // CLB
                4'h1: n_cy = 1'b0;                                               // CLC
                4'h2: begin t = {1'b0, acc} + 5'd1; n_acc = t[3:0]; n_cy = t[4]; end // IAC
                4'h3: n_cy = ~cy;                                                // CMC
                4'h4: n_acc = ~acc;                                              // CMA
                4'h5: begin n_acc = {acc[2:0], cy}; n_cy = acc[3]; end           // RAL
                4'h6: begin n_acc = {cy, acc[3:1]}; n_cy = acc[0]; end           // RAR
                4'h7: begin n_acc = {3'b000, cy}; n_cy = 1'b0; end               // TCC
                4'h8: begin t = {1'b0, acc} + 5'd15; n_acc = t[3:0]; n_cy = t[4]; end // DAC
                4'h9: begin n_acc = cy ? 4'd10 : 4'd9; n_cy = 1'b0; end          // TCS
                4'hA: n_cy = 1'b1;                                               // STC
                4'hB: if (cy || acc > 4'd9) begin                                // DAA
                          t = {1'b0, acc} + 5'd6; n_acc = t[3:0]; n_cy = cy | t[4];
                      end
                4'hC: case (acc)                                                 // KBP
                          4'd0: n_acc = 4'd0;
                          4'd1: n_acc = 4'd1;
                          4'd2: n_acc = 4'd2;
                          4'd4: n_acc = 4'd3;
                          4'd8: n_acc = 4'd4;
                          default: n_acc = 4'd15;
                      endcase
                default: ;                                                       // FD DCL, FE, FF: unchanged
            endcase
        end else begin
            case (op[1:0])
                2'b01: begin t = {1'b0, acc} + {1'b0, b} + {4'b0, cy};   n_acc = t[3:0]; n_cy = t[4]; end // ADD, ADM
                2'b10: begin t = {1'b0, acc} + {1'b0, ~b} + {4'b0, ~cy}; n_acc = t[3:0]; n_cy = t[4]; end // SUB, SBM
                2'b11: n_acc = b;                                                                        // LD, XCH, ...
                default: ;
            endcase
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            acc <= 4'd0;
            cy  <= 1'b0;
        end else if (we) begin
            acc <= n_acc;
            cy  <= n_cy;
        end
    end
endmodule

// Ada: address stack, circular model of spec 3. Ports: docs/blocks.md section 2.
module i4004_addr (
    input  wire        clk,
    input  wire        reset,
    output wire [11:0] pc,
    input  wire        inc,
    input  wire        load_low,
    input  wire        load_full,
    input  wire        push,
    input  wire        pop,
    input  wire [11:0] load_val
);
    reg [11:0] slot [0:3];
    reg [1:0]  sp;
    integer i;

    assign pc = slot[sp];

    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 4; i = i + 1) slot[i] <= 12'd0;
            sp <= 2'd0;
        end else begin
            if (push) begin
                sp <= sp + 2'd1;
                if (load_full) slot[sp + 2'd1] <= load_val;   // JMS: target goes to the new slot
            end else if (pop) begin
                sp <= sp - 2'd1;
            end else if (load_full) begin
                slot[sp] <= load_val;
            end else if (load_low) begin
                slot[sp][7:0] <= load_val[7:0];
            end else if (inc) begin
                slot[sp] <= slot[sp] + 12'd1;
            end
        end
    end
endmodule

// Ada: MCS-4 ROM, 256 x 8 plus a 4-bit I/O port. Ports: docs/blocks.md section 2. Behaviour: spec 6.3 and 7.
// The chip keeps its own period counter: the period after sync = 1 is A1 (period 0).
module i4001 #(
    parameter [3:0] CHIP    = 4'd0,
    parameter       PORT_IN = 1'b0,
    parameter       ROM_FILE = ""
) (
    input  wire       clk,
    input  wire       reset,
    input  wire       sync,
    input  wire       cm_rom,
    input  wire [3:0] bus,
    output wire [3:0] d_out,
    output wire       d_oe,
    input  wire [3:0] io_in,
    output reg  [3:0] io_out
);
    reg [7:0] rom [0:255];
    reg [2:0] period;      // 0 = A1 ... 7 = X3
    reg [7:0] addr;        // latched at A1, A2
    reg       sel;         // this chip was addressed at A3 (cm_rom = 1, bus = CHIP)
    reg       io;          // cm_rom = 1 at M2: the word is an I/O instruction
    reg [3:0] opa;         // OPA, read from the bus at M2
    reg [3:0] src_hi;      // high nibble of the last SRC (cm_rom = 1 at X2)
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1) rom[i] = 8'h00;
        if (ROM_FILE != "") $readmemh(ROM_FILE, rom);
    end

    wire src_me = (src_hi == CHIP);
    wire [7:0] word = rom[addr];

    // M1: OPR, M2: OPA, X2 of RDR: the port (output-configured ports read 0000)
    wire drv_m1  = sel && period == 3'd3;
    wire drv_m2  = sel && period == 3'd4;
    wire drv_rdr = io && opa == 4'hA && src_me && period == 3'd6;

    assign d_oe  = drv_m1 | drv_m2 | drv_rdr;
    assign d_out = drv_m1  ? word[7:4] :
                   drv_m2  ? word[3:0] :
                   drv_rdr ? (PORT_IN ? io_in : 4'h0) : 4'h0;

    always @(posedge clk) begin
        if (reset) begin
            period <= 3'd0;
            addr   <= 8'd0;
            sel    <= 1'b0;
            io     <= 1'b0;
            opa    <= 4'd0;
            src_hi <= 4'd0;
            io_out <= 4'd0;
        end else begin
            period <= sync ? 3'd0 : period + 3'd1;
            case (period)
                3'd0: addr[3:0] <= bus;
                3'd1: addr[7:4] <= bus;
                3'd2: sel <= cm_rom && (bus == CHIP);
                3'd4: begin io <= cm_rom; opa <= bus; end
                3'd6: begin
                    if (cm_rom) src_hi <= bus;                                    // SRC
                    else if (io && opa == 4'h2 && src_me && !PORT_IN) io_out <= bus; // WRR
                end
                default: ;
            endcase
        end
    end
endmodule

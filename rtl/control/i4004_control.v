// i4004_control: sequencing, decode and pins (spec sections 4-6, blocks.md section 2).
//
// Strobe schedule (all strobes are combinational on `period`, applied by the
// edge that ends that period):
//   M1 edge : fetch_hi <= d_in            M2 edge : fetch_lo <= d_in
//   M2 edge : pc_inc (every normal fetch; not FIN's data fetch), so pc is
//             already past the word when X3 loads/pushes/pops it
//   X2 edge : rd_data <= d_in (RDM/RDR/ADM/SBM/RDn), src_addr <= pair (SRC)
//   X3 edge : all register/ALU/pc effects, ir/second/test_s/ram_bank update
module i4004_control (
    input  wire        clk,
    input  wire        reset,
    input  wire [2:0]  period,
    input  wire        test,
    input  wire [3:0]  d_in,
    output wire [3:0]  d_out,
    output wire        d_oe,
    output wire        cm_rom,
    output wire [3:0]  cm_ram,
    input  wire [3:0]  acc,
    input  wire        cy,
    input  wire [11:0] pc,
    input  wire [3:0]  r_data,
    input  wire [3:0]  r_inc,
    input  wire [7:0]  p_data,
    output reg         alu_we,
    output reg  [4:0]  alu_op,
    output reg  [3:0]  alu_b,
    output wire [3:0]  reg_sel,
    output reg         r_we,
    output reg  [3:0]  r_wdata,
    output reg         p_we,
    output reg  [7:0]  p_wdata,
    output reg         pc_inc,
    output reg         pc_load_low,
    output reg         pc_load_full,
    output reg         pc_push,
    output reg         pc_pop,
    output reg  [11:0] pc_load_val
);
    localparam A1 = 3'd0, A2 = 3'd1, A3 = 3'd2, M1 = 3'd3,
               M2 = 3'd4, X2 = 3'd6, X3 = 3'd7;

    // state
    reg [7:0] ir;          // first word of a 2-word instruction / FIN
    reg       second;      // this cycle is the second cycle of ir
    reg [3:0] fetch_hi;    // word fetched this cycle (OPR / high nibble)
    reg [3:0] fetch_lo;    // (OPA / low nibble)
    reg [3:0] rd_data;     // d_in captured at X2
    reg [3:0] src_addr;    // low nibble only is ever driven (X3); spec's 8-bit src_addr high half is the pair
    // verilator lint_off UNUSEDSIGNAL
    reg [3:0] src_hi;      // spec src_addr[7:4], kept for the model
    // verilator lint_on UNUSEDSIGNAL
    reg [2:0] ram_bank;
    reg       test_s;      // TEST sampled at end of X3 of first cycle

    // instruction currently being executed
    wire [3:0] opr = second ? ir[7:4] : fetch_hi;
    wire [3:0] opa = second ? ir[3:0] : fetch_lo;

    wire is_fin = (opr == 4'h3) & ~opa[0];
    wire two_word = (opr == 4'h1) | (opr == 4'h4) | (opr == 4'h5) | (opr == 4'h7) |
                    ((opr == 4'h2) & ~opa[0]) | is_fin;
    wire is_src = (opr == 4'h2) & opa[0];
    wire is_io  = (opr == 4'hE);
    wire io_wr  = is_io & ~opa[3];            // WRM WMP WRR WPM WR0-3
    wire first  = ~second;

    // CM-RAM lines selected by ram_bank (spec 6.5)
    reg [3:0] lines;
    always @(*) begin
        case (ram_bank)
            3'b000: lines = 4'b0001;
            3'b001: lines = 4'b0010;
            3'b010: lines = 4'b0100;
            3'b011: lines = 4'b0110;
            3'b100: lines = 4'b1000;
            3'b101: lines = 4'b1010;
            3'b110: lines = 4'b1100;
            default: lines = 4'b1110;
        endcase
    end

    // ---------------- pins ----------------
    wire fin2   = second & is_fin;
    wire a_ph   = (period == A1) | (period == A2) | (period == A3);
    wire io_c   = first & is_io;              // valid from M2 on
    wire src_c  = first & is_src;             // valid from X2 on
    wire [11:0] a = fin2 ? {pc[11:8], p_data} : pc;

    reg [3:0] dout_r;
    reg       doe_r;
    always @(*) begin
        dout_r = 4'd0;
        doe_r  = 1'b0;
        case (period)
            A1: begin doe_r = 1'b1; dout_r = a[3:0];  end
            A2: begin doe_r = 1'b1; dout_r = a[7:4];  end
            A3: begin doe_r = 1'b1; dout_r = a[11:8]; end
            X2: begin
                if (src_c)           begin doe_r = 1'b1; dout_r = p_data[7:4]; end
                else if (first & io_wr) begin doe_r = 1'b1; dout_r = acc;      end
            end
            X3: if (src_c) begin doe_r = 1'b1; dout_r = src_addr; end
            default: ;
        endcase
    end
    assign d_oe = doe_r & ~reset;
    assign d_out = dout_r;

    wire rom_r = (period == A3) | ((period == M2) & io_c) | ((period == X2) & src_c);
    assign cm_rom = rom_r & ~reset;
    assign cm_ram = (rom_r & ~reset) ? lines : 4'b0000;

    // FIN's second cycle reads P0 during A1-A3, then Pp when the byte is written
    assign reg_sel = (fin2 & a_ph) ? 4'd0 : opa;

    // ---------------- strobes ----------------
    wire [7:0] b_word = {fetch_hi, fetch_lo};   // second word, valid from X1
    wire cond = (opa[2] & (acc == 4'd0)) | (opa[1] & cy) | (opa[0] & ~test_s);
    wire jcn_jump = cond ^ opa[3];

    always @(*) begin
        alu_we = 1'b0; alu_op = 5'b00000; alu_b = 4'd0;
        r_we = 1'b0; r_wdata = 4'd0; p_we = 1'b0; p_wdata = 8'd0;
        pc_inc = 1'b0; pc_load_low = 1'b0; pc_load_full = 1'b0;
        pc_push = 1'b0; pc_pop = 1'b0; pc_load_val = 12'd0;

        if (!reset) begin
            // every normal fetch advances pc at M2 (not FIN's data fetch)
            if (period == M2 && !(second && is_fin)) pc_inc = 1'b1;

            if (period == X3) begin
                if (first) begin
                    case (opr)
                        4'h6: begin r_we = 1'b1; r_wdata = r_inc; end              // INC
                        4'h8: begin alu_we = 1'b1; alu_op = 5'b00001; alu_b = r_data; end // ADD
                        4'h9: begin alu_we = 1'b1; alu_op = 5'b00010; alu_b = r_data; end // SUB
                        4'hA: begin alu_we = 1'b1; alu_op = 5'b00011; alu_b = r_data; end // LD
                        4'hB: begin                                                // XCH
                            alu_we = 1'b1; alu_op = 5'b00011; alu_b = r_data;
                            r_we = 1'b1; r_wdata = acc;
                        end
                        4'hC: begin                                                // BBL
                            pc_pop = 1'b1;
                            alu_we = 1'b1; alu_op = 5'b00011; alu_b = opa;
                        end
                        4'hD: begin alu_we = 1'b1; alu_op = 5'b00011; alu_b = opa; end // LDM
                        4'h3: if (opa[0]) begin                                    // JIN
                            pc_load_low = 1'b1; pc_load_val = {4'd0, p_data};
                        end
                        4'hE: begin
                            case (opa)
                                4'h8: begin alu_we = 1'b1; alu_op = 5'b00010; alu_b = rd_data; end // SBM
                                4'h9, 4'hA, 4'hC, 4'hD, 4'hE, 4'hF: begin                           // RDM RDR RDn
                                    alu_we = 1'b1; alu_op = 5'b00011; alu_b = rd_data;
                                end
                                4'hB: begin alu_we = 1'b1; alu_op = 5'b00001; alu_b = rd_data; end // ADM
                                default: ;
                            endcase
                        end
                        4'hF: begin alu_we = 1'b1; alu_op = {1'b1, opa}; end       // accumulator group
                        default: ;
                    endcase
                end else begin
                    case (opr)
                        4'h1: if (jcn_jump) begin                                  // JCN
                            pc_load_low = 1'b1; pc_load_val = {4'd0, b_word};
                        end
                        4'h2: begin p_we = 1'b1; p_wdata = b_word; end             // FIM
                        4'h3: begin p_we = 1'b1; p_wdata = b_word; end             // FIN
                        4'h4: begin pc_load_full = 1'b1; pc_load_val = {opa, b_word}; end // JUN
                        4'h5: begin                                                // JMS
                            pc_push = 1'b1; pc_load_full = 1'b1; pc_load_val = {opa, b_word};
                        end
                        4'h7: begin                                                // ISZ
                            r_we = 1'b1; r_wdata = r_inc;
                            if (r_inc != 4'd0) begin
                                pc_load_low = 1'b1; pc_load_val = {4'd0, b_word};
                            end
                        end
                        default: ;
                    endcase
                end
            end
        end
    end

    // ---------------- state ----------------
    always @(posedge clk) begin
        if (reset) begin
            ir <= 8'd0;
            second <= 1'b0;
            fetch_hi <= 4'd0;
            fetch_lo <= 4'd0;
            rd_data <= 4'd0;
            src_addr <= 4'd0;
            src_hi <= 4'd0;
            ram_bank <= 3'd0;
            test_s <= 1'b0;
        end else begin
            case (period)
                M1: fetch_hi <= d_in;
                M2: fetch_lo <= d_in;
                X2: begin
                    rd_data <= d_in;
                    if (src_c) {src_hi, src_addr} <= p_data;
                end
                X3: begin
                    if (first) begin
                        ir <= {fetch_hi, fetch_lo};
                        second <= two_word;
                        test_s <= test;
                        if (opr == 4'hF && opa == 4'hD) ram_bank <= acc[2:0];  // DCL
                    end else begin
                        second <= 1'b0;
                    end
                end
                default: ;
            endcase
        end
    end
endmodule

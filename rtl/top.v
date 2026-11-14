// verilator lint_off DECLFILENAME
// i4004: CPU top level. Wiring only (blocks.md section 2). Pins per spec section 2.
module i4004 (
    input  wire       clk,
    input  wire       reset,
    input  wire       test,
    input  wire [3:0] d_in,
    output wire [3:0] d_out,
    output wire       d_oe,
    output wire       sync,
    output wire       cm_rom,
    output wire [3:0] cm_ram
);
    wire [2:0]  period;
    wire        alu_we, r_we, p_we;
    wire [4:0]  alu_op;
    wire [3:0]  alu_b, acc, reg_sel, r_wdata, r_data, r_inc;
    wire        cy;
    wire [7:0]  p_wdata, p_data;
    wire        pc_inc, pc_load_low, pc_load_full, pc_push, pc_pop;
    wire [11:0] pc, pc_load_val;

    i4004_timing u_timing (.clk(clk), .reset(reset), .period(period), .sync(sync));

    i4004_control u_control (
        .clk(clk), .reset(reset), .period(period), .test(test), .d_in(d_in),
        .d_out(d_out), .d_oe(d_oe), .cm_rom(cm_rom), .cm_ram(cm_ram),
        .acc(acc), .cy(cy), .pc(pc),
        .r_data(r_data), .r_inc(r_inc), .p_data(p_data),
        .alu_we(alu_we), .alu_op(alu_op), .alu_b(alu_b),
        .reg_sel(reg_sel), .r_we(r_we), .r_wdata(r_wdata), .p_we(p_we), .p_wdata(p_wdata),
        .pc_inc(pc_inc), .pc_load_low(pc_load_low), .pc_load_full(pc_load_full),
        .pc_push(pc_push), .pc_pop(pc_pop), .pc_load_val(pc_load_val)
    );

    i4004_alu u_alu (
        .clk(clk), .reset(reset), .we(alu_we), .op(alu_op), .b(alu_b), .acc(acc), .cy(cy)
    );

    i4004_regs u_regs (
        .clk(clk), .reset(reset), .sel(reg_sel), .r_data(r_data), .r_inc(r_inc), .p_data(p_data),
        .r_we(r_we), .r_wdata(r_wdata), .p_we(p_we), .p_wdata(p_wdata)
    );

    i4004_addr u_addr (
        .clk(clk), .reset(reset), .pc(pc), .inc(pc_inc), .load_low(pc_load_low),
        .load_full(pc_load_full), .push(pc_push), .pop(pc_pop), .load_val(pc_load_val)
    );
endmodule

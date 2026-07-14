`include "CPU_def.vh"
module EXU(
    input         clk,
    input         rst,

    input  [31:0] pc,
    input  [31:0] rdata1,
    input  [31:0] rdata2,
    input  [31:0] imm32,

    input         flush,
    input         ex_valid,
    input         exmem_ready,

    input  [31:0] fp_rdata1,
    input  [31:0] fp_rdata2,

    input  [3:0]  branch,

    input         ALUSrc1,
    input  [1:0]  ALUSrc2,
    input  [2:0]  alsl_shift,

    input  [1:0]  UnitSel,
    input  [2:0]  MDUctr,
    input  [3:0]  FPUctr,
    input  [4:0]  ALUctr,

    output        ex_busy,
    output        ex_ready,
    output        ex_res_valid,

    output reg [31:0] ex_res,
    output     [31:0] fp_to_gp_data,
    output     [31:0] gp_to_fp_data,

    output     [31:0] branch_target,
    output            take_branch,
    output            branch_valid,
    output            branch_cond,
    output            branch_jirl,

    output            ex_exc_valid,
    output      [5:0] ex_exc_ecode,
    output reg  [8:0] ex_exc_esubcode
);

    reg [31:0] op_b;

    wire [31:0] op_a = ALUSrc1 ? pc : rdata1;

    wire [31:0] alu_res;
    wire [31:0] mdu_res;
    wire [31:0] fpu_res;

    wire mdu_ready;
    wire fpu_ready;
    wire mdu_busy;
    wire fpu_busy;

    wire mdu_error_raw;

    assign fp_to_gp_data = fp_rdata1;
    assign gp_to_fp_data = rdata1;

    always @(*) begin
        case (ALUSrc2)
            2'b00:   op_b = rdata2;
            2'b01:   op_b = imm32;
            2'b10:   op_b = 32'd4;
            default: op_b = rdata2;
        endcase
    end

    ALU u_alu(
        .A(op_a),
        .B(op_b),
        .alsl_shift(alsl_shift),
        .alu_op(ALUctr),
        .alu_res(alu_res)
    );

    wire is_mdu_inst = ex_valid && (UnitSel == `MDU_use);
    wire is_fpu_inst = ex_valid && (UnitSel == `FPU_use) && (FPUctr != `FP_movs);
    wire is_multi    = is_mdu_inst || is_fpu_inst;

    reg        multi_busy;
    reg        multi_done_hold;
    reg        multi_is_mdu;
    reg        multi_is_fpu;
    reg [31:0] multi_result_hold;
    reg        multi_error_hold;

    wire start_multi = ex_valid && is_multi && !multi_busy && !multi_done_hold;
    wire mdu_start   = start_multi && is_mdu_inst;
    wire fpu_start   = start_multi && is_fpu_inst;

    assign ex_ready     = !ex_valid || !is_multi || multi_done_hold;
    assign ex_busy      = ex_valid && is_multi && !multi_done_hold;
    assign ex_res_valid = ex_valid && ex_ready;

    wire result_accepted = ex_res_valid && exmem_ready;

    FPU u_fpu(
        .clk(clk),
        .rst(rst),
        .en(fpu_start),
        .A(fp_rdata1),
        .B(fp_rdata2),
        .fpu_op(FPUctr),
        .ready(fpu_ready),
        .busy(fpu_busy),
        .fpu_res(fpu_res)
    );

    MDU u_mdu(
        .clk(clk),
        .rst(rst),
        .en(mdu_start),
        .A(rdata1),
        .B(rdata2),
        .mdu_op(MDUctr),
        .ready(mdu_ready),
        .busy(mdu_busy),
        .mdu_res(mdu_res),
        .error(mdu_error_raw)
    );

    always @(posedge clk or negedge rst) begin
        if (!rst || flush) begin
            multi_busy        <= 1'b0;
            multi_done_hold   <= 1'b0;
            multi_is_mdu      <= 1'b0;
            multi_is_fpu      <= 1'b0;
            multi_result_hold <= 32'b0;
            multi_error_hold  <= 1'b0;
        end
        else begin
            if (start_multi) begin
                multi_busy      <= 1'b1;
                multi_done_hold <= 1'b0;
                multi_is_mdu    <= is_mdu_inst;
                multi_is_fpu    <= is_fpu_inst;
                multi_error_hold<= 1'b0;
            end

            if (multi_busy && multi_is_mdu && mdu_ready) begin
                multi_busy        <= 1'b0;
                multi_done_hold   <= 1'b1;
                multi_result_hold <= mdu_res;
                multi_error_hold  <= mdu_error_raw;
            end

            if (multi_busy && multi_is_fpu && fpu_ready) begin
                multi_busy        <= 1'b0;
                multi_done_hold   <= 1'b1;
                multi_result_hold <= fpu_res;
            end

            if (result_accepted) begin
                multi_done_hold <= 1'b0;
            end
        end
    end

    always @(*) begin
        case (UnitSel)
            `MDU_use: begin
                ex_res = multi_done_hold ? multi_result_hold : mdu_res;
            end

            `FPU_use: begin
                if (FPUctr == `FP_movs)
                    ex_res = fp_rdata1;
                else
                    ex_res = multi_result_hold;
            end

            default: begin
                ex_res = alu_res;
            end
        endcase
    end

    BRU u_bru(
        .pc(pc),
        .imm32(imm32),
        .rdata1(rdata1),
        .rdata2(rdata2),
        .branch(branch),

        .branch_target(branch_target),
        .take_branch(take_branch),

        .branch_valid(branch_valid),
        .branch_cond(branch_cond),
        .branch_jirl(branch_jirl)
    );

    wire ex_exc_md_valid = ex_valid && (UnitSel == `MDU_use) && multi_done_hold && multi_error_hold;

    assign ex_exc_valid = ex_exc_md_valid;

    assign ex_exc_ecode = ex_exc_valid ? `ECODE_FPE : 6'b0;

    always @(*) begin
        case(1'b1)
            ex_exc_md_valid: ex_exc_esubcode = 9'd1;
            default: ex_exc_esubcode = 9'd0;
        endcase
    end

endmodule
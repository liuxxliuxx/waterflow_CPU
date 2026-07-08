`include "CPU_def.vh"
module BRU(
    input[31:0]   pc,
    input[31:0]   imm32,
    input[31:0]   rdata1,
    input[31:0]   rdata2,
    input[3:0]    branch,


    output[31:0]  branch_target,
    output reg    take_branch,

    output        branch_valid,
    output        branch_cond, //条件分支
    output        branch_jirl
    );
    
    assign branch_valid = (branch != `BR_NONE);
    assign branch_cond  = (branch == `BR_BEQ ) ||
                          (branch == `BR_BNE ) ||
                          (branch == `BR_BLT ) ||
                          (branch == `BR_BGE ) ||
                          (branch == `BR_BLTU) ||
                          (branch == `BR_BGEU) ||
                          (branch == `BR_BEQZ) ||
                          (branch == `BR_BNEZ);
    assign branch_jirl  = (branch == `BR_JIRL);
    
    wire[31:0] op_a = (branch == `BR_JIRL) ? rdata1 : pc;
    
    adder add_bne(
        .A(op_a),
        .B(imm32),
        .cin(1'b0),
        .Sum(branch_target),
        .cout()
    );

    wire[31:0] sub_res;
    wire cout;

    wire[31:0] op_A = rdata1;
    wire[31:0] op_B = ~rdata2;

    adder u_sub(
        .A(op_A),
        .B(op_B),
        .cin(1'b1),
        .Sum(sub_res),
        .cout(cout)
    );

    wire OF = (op_A[31] == op_B[31])&&(sub_res[31] != op_A[31]);
    wire ZF = (sub_res == 32'd0);
    wire CF = ~cout;
    wire SF = sub_res[31];
    
    always @(*) begin
        case(branch)
            `BR_BEQ:  take_branch = ZF;
            `BR_BNE:  take_branch = ~ZF;
            `BR_BLT:  take_branch = SF ^ OF;
            `BR_BGE:  take_branch = ~(SF ^ OF);
            `BR_BLTU: take_branch = CF;
            `BR_BGEU: take_branch = ~(CF);
            `BR_BEQZ: take_branch = (rdata1 == 32'd0);
            `BR_BNEZ: take_branch = (rdata1 != 32'd0);
            `BR_B:    take_branch = 1'b1;
            `BR_JIRL: take_branch = 1'b1;

            default: take_branch = 1'b0;
        endcase
    end
endmodule

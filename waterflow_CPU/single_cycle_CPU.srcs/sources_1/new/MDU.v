`include "CPU_def.vh"

module MDU(
    input clk,
    input rst,
    input en,
    input [2:0] mdu_op,
    input [31:0] A,
    input [31:0] B,

    output busy,
    output ready,
    output [31:0] mdu_res,
    output error
    );

    reg  [2:0]  op_r;
    reg  [31:0] a_r;
    reg  [31:0] b_r;
    reg  [31:0] result_hold;
    reg         invalid_ready_r;

    wire op_is_mul = (mdu_op == `MDU_MULW)   ||
                     (mdu_op == `MDU_MULHW)  ||
                     (mdu_op == `MDU_MULHWU);

    wire op_is_div = (mdu_op == `MDU_DIVW)   ||
                     (mdu_op == `MDU_MODW)   ||
                     (mdu_op == `MDU_DIVWU)  ||
                     (mdu_op == `MDU_MODWU);

    wire mul_start = en && op_is_mul;
    wire div_start = en && op_is_div;

    wire        mul_busy;
    wire        mul_ready;
    wire [63:0] mul_product_signed;

    booth_wallace u_mul_pipe(
        .clk     (clk),
        .rst     (rst),
        .start   (mul_start),
        .A       (A),
        .B       (B),
        .busy    (mul_busy),
        .ready   (mul_ready),
        .Product (mul_product_signed)
    );

    wire        div_busy;
    wire        div_ready;
    wire [31:0] div_quotient;
    wire [31:0] div_remainder;
    wire        div_signed = (mdu_op == `MDU_DIVW) || (mdu_op == `MDU_MODW);

    diver u_diver(
        .clk         (clk),
        .rst         (rst),
        .start       (div_start),
        .signed_mode (div_signed),
        .A           (A),
        .B           (B),
        .busy        (div_busy),
        .ready       (div_ready),
        .quotient    (div_quotient),
        .remainder   (div_remainder),
        .error       (error)
    );

    wire [31:0] unsigned_high_fix =
        mul_product_signed[63:32] +
        (a_r[31] ? b_r : 32'b0) +
        (b_r[31] ? a_r : 32'b0);

    reg [31:0] mul_result;
    always @(*) begin
        case (op_r)
            `MDU_MULW:   mul_result = mul_product_signed[31:0];
            `MDU_MULHW:  mul_result = mul_product_signed[63:32];
            `MDU_MULHWU: mul_result = unsigned_high_fix;
            default:     mul_result = 32'b0;
        endcase
    end

    reg [31:0] div_result;
    always @(*) begin
        case (op_r)
            `MDU_DIVW,
            `MDU_DIVWU: div_result = div_quotient;
            `MDU_MODW,
            `MDU_MODWU: div_result = div_remainder;
            default:    div_result = 32'b0;
        endcase
    end

    wire op_ready = mul_ready || div_ready || invalid_ready_r;
    wire [31:0] ready_result =
        mul_ready       ? mul_result :
        div_ready       ? div_result :
        invalid_ready_r ? 32'b0     :
                          result_hold;

    assign ready   = op_ready;
    assign busy    = mul_busy || div_busy;
    assign mdu_res = op_ready ? ready_result : result_hold;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            op_r            <= `MDU_NONE;
            a_r             <= 32'b0;
            b_r             <= 32'b0;
            result_hold     <= 32'b0;
            invalid_ready_r <= 1'b0;
        end
        else begin
            invalid_ready_r <= 1'b0;

            if (en) begin
                op_r <= mdu_op;
                a_r  <= A;
                b_r  <= B;

                if (!op_is_mul && !op_is_div) begin
                    result_hold     <= 32'b0;
                    invalid_ready_r <= 1'b1;
                end
            end
            else if (mul_ready) begin
                result_hold <= mul_result;
            end
            else if (div_ready) begin
                result_hold <= div_result;
            end
        end
    end

endmodule




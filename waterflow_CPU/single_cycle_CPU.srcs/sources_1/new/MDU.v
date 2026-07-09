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
    output [31:0] mdu_res
    );

    reg        ready_r;
    reg [31:0] result_r;

    wire signed [63:0] signed_product =
        $signed({{32{A[31]}}, A}) * $signed({{32{B[31]}}, B});
    wire        [63:0] unsigned_product = A * B;

    wire [31:0] abs_A = A[31] ? (~A + 32'd1) : A;
    wire [31:0] abs_B = B[31] ? (~B + 32'd1) : B;
    wire [31:0] divw_abs_q = (B == 32'b0) ? 32'b0 : abs_A / abs_B;
    wire [31:0] modw_abs_r = (B == 32'b0) ? 32'b0 : abs_A % abs_B;
    wire [31:0] divw_result = (A[31] ^ B[31]) ? (~divw_abs_q + 32'd1) : divw_abs_q;
    wire [31:0] modw_result = A[31] ? (~modw_abs_r + 32'd1) : modw_abs_r;

    assign ready   = ready_r;
    assign busy    = en && !ready_r;
    assign mdu_res = result_r;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            ready_r  <= 1'b0;
            result_r <= 32'b0;
        end
        else begin
            ready_r <= en;

            if (en) begin
                case (mdu_op)
                    `MDU_MULW:   result_r <= signed_product[31:0];
                    `MDU_MULHW:  result_r <= signed_product[63:32];
                    `MDU_MULHWU: result_r <= unsigned_product[63:32];
                    `MDU_DIVW:   result_r <= divw_result;
                    `MDU_MODW:   result_r <= modw_result;
                    `MDU_DIVWU:  result_r <= (B == 32'b0) ? 32'b0 : A / B;
                    `MDU_MODWU:  result_r <= (B == 32'b0) ? 32'b0 : A % B;
                    default:     result_r <= 32'b0;
                endcase
            end
        end
    end

endmodule

`include "CPU_def.vh"

module FPU(
    input         clk,
    input         rst,
    input         en,
    input  [31:0] A,
    input  [31:0] B,
    input  [3:0]  fpu_op,

    output        ready,
    output        busy,
    output [31:0] fpu_res
);

    reg        ready_r;
    reg [31:0] result_r;

    wire [31:0] addsub_res;
    wire [31:0] mul_res;
    wire        mul_busy;
    wire        mul_ready;
    wire        mul_start = en && (fpu_op == `FP_muls);
    wire        addsub_sub = (fpu_op == `FP_subs);

    fp_add_s u_fp_add_s(
        .sub(addsub_sub),
        .A(A),
        .B(B),
        .R(addsub_res)
    );

    fp_mul_s u_fp_mul_s(
        .clk   (clk),
        .rst   (rst),
        .start (mul_start),
        .A     (A),
        .B     (B),
        .busy  (mul_busy),
        .ready (mul_ready),
        .R     (mul_res)
    );

    assign ready   = ready_r || mul_ready;
    assign busy    = mul_busy || (en && (fpu_op != `FP_muls));
    assign fpu_res = mul_ready ? mul_res : result_r;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            ready_r  <= 1'b0;
            result_r <= 32'b0;
        end
        else begin
            ready_r <= 1'b0;

            if (en && (fpu_op != `FP_muls)) begin
                ready_r <= 1'b1;
                case (fpu_op)
                    `FP_adds: result_r <= addsub_res;
                    `FP_subs: result_r <= addsub_res;
                    default:  result_r <= 32'b0;
                endcase
            end
        end
    end

endmodule

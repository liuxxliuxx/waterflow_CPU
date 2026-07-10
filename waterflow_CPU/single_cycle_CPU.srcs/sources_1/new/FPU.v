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
    output [31:0] fpu_res,
    output        fpu_exception,
    output [1:0]  exc_code
);

    reg        ready_r;
    reg [31:0] result_r;
    reg [1:0]  exc_code_r;

    wire [31:0] addsub_res;
    wire        addsub_exc_of;
    wire        addsub_exc_uf;
    wire [31:0] mul_res;
    wire        mul_exc_of;
    wire        mul_exc_uf;
    wire        mul_busy;
    wire        mul_ready;
    wire        mul_start = en && (fpu_op == `FP_muls);
    wire        addsub_sub = (fpu_op == `FP_subs);

    fp_add_s u_fp_add_s(
        .sub    (addsub_sub),
        .A      (A),
        .B      (B),
        .R      (addsub_res),
        .exc_of (addsub_exc_of),
        .exc_uf (addsub_exc_uf)
    );

    fp_mul_s u_fp_mul_s(
        .clk    (clk),
        .rst    (rst),
        .start  (mul_start),
        .A      (A),
        .B      (B),
        .busy   (mul_busy),
        .ready  (mul_ready),
        .R      (mul_res),
        .exc_of (mul_exc_of),
        .exc_uf (mul_exc_uf)
    );

    wire [1:0] mul_exc_code = mul_exc_of ? 2'b10 :
                               mul_exc_uf ? 2'b11 : 2'b00;

    assign ready         = ready_r || mul_ready;
    assign busy          = mul_busy || (en && (fpu_op != `FP_muls));
    assign fpu_res       = mul_ready ? mul_res : result_r;
    assign exc_code       = mul_ready ? mul_exc_code : exc_code_r;
    assign fpu_exception  = |exc_code;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            ready_r    <= 1'b0;
            result_r   <= 32'b0;
            exc_code_r <= 2'b00;
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

                if (addsub_exc_of)
                    exc_code_r <= 2'b10;
                else if (addsub_exc_uf)
                    exc_code_r <= 2'b11;
                else
                    exc_code_r <= 2'b00;
            end
        end
    end

endmodule

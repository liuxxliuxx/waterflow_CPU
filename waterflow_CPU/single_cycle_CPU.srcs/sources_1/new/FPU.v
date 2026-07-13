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

    wire addsub_start = en &&
                        ((fpu_op == `FP_adds) ||
                         (fpu_op == `FP_subs));
    wire addsub_sub = (fpu_op == `FP_subs);
    wire mul_start  = en && (fpu_op == `FP_muls);

    wire [31:0] addsub_res;
    wire        addsub_exc_of;
    wire        addsub_exc_uf;
    wire        addsub_busy;
    wire        addsub_ready;

    wire [31:0] mul_res;
    wire        mul_exc_of;
    wire        mul_exc_uf;
    wire        mul_busy;
    wire        mul_ready;

    reg invalid_ready_r;

    fp_add_s u_fp_add_s(
        .clk    (clk),
        .rst    (rst),
        .start  (addsub_start),
        .sub    (addsub_sub),
        .A      (A),
        .B      (B),
        .busy   (addsub_busy),
        .ready  (addsub_ready),
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

    wire [1:0] addsub_exc_code = addsub_exc_of ? 2'b10 :
                                  addsub_exc_uf ? 2'b11 : 2'b00;
    wire [1:0] mul_exc_code = mul_exc_of ? 2'b10 :
                               mul_exc_uf ? 2'b11 : 2'b00;

    assign ready = addsub_ready || mul_ready || invalid_ready_r;
    assign busy  = addsub_busy || mul_busy;

    assign fpu_res = mul_ready ? mul_res :
                     addsub_ready ? addsub_res : 32'b0;
    assign exc_code = mul_ready ? mul_exc_code :
                      addsub_ready ? addsub_exc_code : 2'b00;
    assign fpu_exception = |exc_code;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            invalid_ready_r <= 1'b0;
        end
        else begin
            invalid_ready_r <= en &&
                               (fpu_op != `FP_adds) &&
                               (fpu_op != `FP_subs) &&
                               (fpu_op != `FP_muls);
        end
    end

endmodule

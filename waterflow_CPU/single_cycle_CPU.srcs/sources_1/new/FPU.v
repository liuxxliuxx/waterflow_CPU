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

    assign ready   = ready_r;
    assign busy    = en && !ready_r;
    assign fpu_res = result_r;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            ready_r  <= 1'b0;
            result_r <= 32'b0;
        end
        else begin
            ready_r <= en;

            if (en) begin
                case (fpu_op)
                    `FP_movs: result_r <= A;
                    default:  result_r <= 32'b0;
                endcase
            end
        end
    end

endmodule

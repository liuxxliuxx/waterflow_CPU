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
    
    
endmodule

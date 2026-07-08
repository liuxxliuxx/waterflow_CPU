module MDU(
    input clk,
    input rst,
    input en,
    input[2:0] mdu_op,
    input[31:0] A,
    input[31:0] B,
    
    output busy,
    output ready,
    output[31:0] mdu_res
    );

    booth_wallace u_muxer(.A(A),.B(B),.Product(mux_res));

    diver u_diver(.clk(clk),.rst(rst),.A(A),.B(B),.issue(issue),.kill(kill),.busy(busy),.done(done),.Quotient(div_res),.Remainder(mod_res));

endmodule

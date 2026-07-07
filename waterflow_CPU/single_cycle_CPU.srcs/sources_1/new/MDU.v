module MDU(
    input clk,
    input rst,
    input[2:0] mdu_op,
    input[31:0] A,
    input[31:0] B,
    input issue,
    input kill,
    output busy,
    output done,
    output[31:0] res
    
    );

    booth_wallace u_muxer(.A(A),.B(B),.Product(mux_res));

    diver u_diver(.clk(clk),.rst(rst),.A(A),.B(B),.issue(issue),.kill(kill),.busy(busy),.done(done),.Quotient(div_res),.Remainder(mod_res));

endmodule

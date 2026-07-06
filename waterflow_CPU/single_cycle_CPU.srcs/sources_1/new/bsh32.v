`timescale 1ns / 1ps
module bsh32(
    input [31:0] A,
    input [4:0]  B,
    input        dir,
    input        issign,
    output[31:0] res
    );
    wire[31:0] res1;
    wire[31:0] res2;
    wire[31:0] res4;
    wire[31:0] res8;
    bsh1 u_bsh1(.A(A),.en(B[0]),.dir(dir),.issign(issign),.res(res1));
    bsh2 u_bsh2(.A(res1),.en(B[1]),.dir(dir),.issign(issign),.res(res2));
    bsh4 u_bsh4(.A(res2),.en(B[2]),.dir(dir),.issign(issign),.res(res4));
    bsh8 u_bsh8(.A(res4),.en(B[3]),.dir(dir),.issign(issign),.res(res8));
    bsh16 u_bsh16(.A(res8),.en(B[4]),.dir(dir),.issign(issign),.res(res));
endmodule

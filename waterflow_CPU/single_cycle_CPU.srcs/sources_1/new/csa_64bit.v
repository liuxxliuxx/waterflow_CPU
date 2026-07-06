module csa_64bit (
    input  wire [63:0] in1,
    input  wire [63:0] in2,
    input  wire [63:0] in3,
    output wire [63:0] sum,
    output wire [63:0] carry
);
    assign sum   = in1 ^ in2 ^ in3; 
    assign carry = ((in1 & in2) | (in2 & in3) | (in1 & in3)) << 1; 
endmodule
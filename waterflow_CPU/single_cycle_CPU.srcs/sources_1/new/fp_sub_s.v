module fp_sub_s(
    input  [31:0] A,
    input  [31:0] B,
    output [31:0] R
);

    wire [31:0] B_neg;

    assign B_neg = {~B[31], B[30:0]};

    fp_add_s u_sub_add(
        .A(A),
        .B(B_neg),
        .R(R)
    );

endmodule
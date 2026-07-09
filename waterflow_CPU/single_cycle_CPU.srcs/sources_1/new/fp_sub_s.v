module fp_sub_s(
    input  [31:0] A,
    input  [31:0] B,
    output [31:0] R
);

    fp_add_s u_sub_add(
        .sub(1'b1),
        .A(A),
        .B(B),
        .R(R)
    );

endmodule

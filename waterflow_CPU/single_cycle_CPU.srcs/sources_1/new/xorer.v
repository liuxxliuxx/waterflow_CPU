module xorer(
    input wire[31:0]  A,
    input wire[31:0]  B,
    output wire[31:0] res
    );
    assign res = A ^ B;
endmodule
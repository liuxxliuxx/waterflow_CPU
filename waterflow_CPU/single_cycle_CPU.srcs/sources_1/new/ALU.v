module ALU(
    input wire[31:0]  A,
    input wire[31:0]  B,
    input wire[3:0]   alu_op,
    output reg[31:0] alu_res,
    output wire       ZF,
    output wire       SF,
    output wire       CF,
    output wire       OF 
    );
    wire[31:0] op_B;
    wire       is_sub;
    wire       cout;
    wire[31:0] add_res;
    wire[31:0] and_res;
    wire[31:0] or_res;
    wire[31:0] xor_res;
    wire[31:0] bsh_res;
    wire[31:0] nor_res;
    wire[63:0] mux_res;
    assign is_sub = (alu_op == 4'b0001 || alu_op == 4'b0110 || alu_op == 4'b0111);
    assign op_B = is_sub ? (~B) : B;
    
    assign ZF = (alu_res == 32'd0);
    assign SF = alu_res[31];
    assign OF = (A[31] == op_B[31])&&(add_res[31] != A[31]);
    
    adder u_adder(.A(A),.B(op_B),.cin(is_sub),.Sum(add_res),.cout(cout));
    
    booth_wallace u_muxer(.A(A),.B(B),.Product(mux_res));
    
    ander u_and(.A(A),.B(B),.res(and_res));
    
    orer u_or(.A(A),.B(B),.res(or_res));
    
    xorer u_xor(.A(A),.B(B),.res(xor_res));
    
    norer u_nor(.A(A),.B(B),.res(nor_res));
    
    bsh32 u_bshl(.A(A),.B(B[4:0]),.dir(alu_op[0]),.issign(alu_op[1]),.res(bsh_res));
    
    assign CF = is_sub ? (~cout) : cout;
    
    wire[31:0] slt_res = {31'b0,add_res[31]^OF};
    wire[31:0] sltu_res = {31'b0,CF};
    
    
    
    always @(*) begin
        case(alu_op)
            4'b0000: alu_res = add_res;
            4'b0001: alu_res = add_res;
            4'b0010: alu_res = mux_res[31:0];
            4'b0011: alu_res = and_res;
            4'b0100: alu_res = or_res;
            4'b0101: alu_res = xor_res;
            4'b0110: alu_res = slt_res;
            4'b0111: alu_res = sltu_res;
            4'b1000: alu_res = bsh_res;
            4'b1001: alu_res = bsh_res;
            4'b1010: alu_res = bsh_res;
            4'b1011: alu_res = bsh_res;
            4'b1100: alu_res = nor_res;
            4'b1101: alu_res = B;
            default: alu_res = 32'd0;
        endcase
    end
    
endmodule

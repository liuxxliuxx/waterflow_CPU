`include "CPU_def.vh"
module ALU(
    input wire[31:0]  A,
    input wire[31:0]  B,
    input wire[4:0]   alu_op,
    input wire[2:0]   alsl_shift,
    output reg[31:0]  alu_res,
    output wire       ZF,
    output wire       SF,
    output wire       CF,
    output wire       OF 
    );

    wire is_sub = (alu_op == `ALU_SUB)  ||
                  (alu_op == `ALU_SLT)  ||
                  (alu_op == `ALU_SLTU);
    
    wire is_inv_logic = (alu_op == `ALU_ANDN) ||
                        (alu_op == `ALU_ORN);

    wire [31:0] op_A = (alu_op==`ALU_ALSL) ? (A<<alsl_shift) : A;
    wire [31:0] op_B = (is_sub) ? ~B : B;
    wire [31:0] logic_B = (is_inv_logic) ? ~B : B;
    
    wire       cout;
    wire[31:0] add_res;
    wire[31:0] and_res;
    wire[31:0] or_res;
    wire[31:0] xor_res;
    wire[31:0] bsh_res;
    wire[31:0] nor_res;
    

    adder u_adder(.A(op_A),.B(op_B),.cin(is_sub),.Sum(add_res),.cout(cout));
    
    ander u_and(.A(A),.B(logic_B),.res(and_res));
    
    orer u_or(.A(A),.B(logic_B),.res(or_res));
    
    xorer u_xor(.A(A),.B(logic_B),.res(xor_res));
    
    norer u_nor(.A(A),.B(logic_B),.res(nor_res));
    
    bsh32 u_bshl(.A(A),.B(B[4:0]),.dir(alu_op[0]),.issign(alu_op[1]),.res(bsh_res));
    

    assign CF = is_sub ? (~cout) : cout;
    assign ZF = (alu_res == 32'd0);
    assign SF = alu_res[31];
    assign OF = (op_A[31] == op_B[31])&&(add_res[31] != op_A[31]);


    wire[31:0] slt_res = {31'b0,add_res[31]^OF};
    wire[31:0] sltu_res = {31'b0,CF};
    wire[31:0] ext_h_res= {{16{A[15]}},A[15:0]};
    wire[31:0] ext_b_res= {{24{A[7]}},A[7:0]};
    wire[31:0] andn_res = and_res;
    wire[31:0] orn_res  = or_res;
    wire[31:0] alsl_res = add_res;
    wire[31:0] maskeqz_res= (B==32'd0) ? 32'd0 : A;
    wire[31:0] masknez_res= (B!=32'd0) ? 32'd0 : A;
    wire[31:0] pcalau_res = {add_res[31:12],12'd0};

    function [31:0] clz32;
        input [31:0] x;
        integer i;
        reg found;
        begin
            clz32 = 32'd0;
            found = 1'b0;
            for (i = 31; i >= 0; i = i - 1) begin
                if (!found) begin
                    if (x[i])
                        found = 1'b1;
                    else
                        clz32 = clz32 + 32'd1;
                end
            end
        end
    endfunction

    function [31:0] ctz32;
        input [31:0] x;
        integer i;
        reg found;
        begin
            ctz32 = 32'd0;
            found = 1'b0;
            for (i = 0; i < 32; i = i + 1) begin
                if (!found) begin
                    if (x[i])
                        found = 1'b1;
                    else
                        ctz32 = ctz32 + 32'd1;
                end
            end
        end
    endfunction

    wire [31:0] clz_res = clz32(A);
    wire [31:0] ctz_res = ctz32(A);
    wire [31:0] clo_res = clz32(~A);
    wire [31:0] cto_res = ctz32(~A);
    
    
    
    always @(*) begin
        case (alu_op)
            `ALU_NOP:      alu_res = 32'b0;
            `ALU_ADD:      alu_res = add_res;
            `ALU_SUB:      alu_res = add_res;
            `ALU_AND:      alu_res = and_res;
            `ALU_OR:       alu_res = or_res;
            `ALU_XOR:      alu_res = xor_res;
            `ALU_NOR:      alu_res = nor_res;
            `ALU_SLT:      alu_res = slt_res;
            `ALU_SLTU:     alu_res = sltu_res;
            `ALU_SLL:      alu_res = bsh_res;
            `ALU_SRL:      alu_res = bsh_res;
            `ALU_SRA:      alu_res = bsh_res;
            `ALU_LU12I:    alu_res = B;
            `ALU_EXT_H:    alu_res = ext_h_res;
            `ALU_EXT_B:    alu_res = ext_b_res;
            `ALU_CLZ:      alu_res = clz_res;
            `ALU_CTZ:      alu_res = ctz_res;
            `ALU_CLO:      alu_res = clo_res;
            `ALU_CTO:      alu_res = cto_res;
            `ALU_ANDN:     alu_res = andn_res;
            `ALU_ORN:      alu_res = orn_res;
            `ALU_ALSL:     alu_res = alsl_res;
            `ALU_MASKEQZ:  alu_res = maskeqz_res;
            `ALU_MASKNEZ:  alu_res = masknez_res;
            `ALU_PCALAU:   alu_res = pcalau_res;
            `ALU_CPUCFG:   alu_res = 32'b0;

            default:       alu_res = 32'b0;
        endcase
    end
    
endmodule

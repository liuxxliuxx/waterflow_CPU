module Sign_Extender(
    input[31:0] imm,
    input[4:0] op,
    output reg[31:0] imm32
    );
    wire[11:0] imm12 = inst[21:10];
    wire[15:0] imm16 = inst[25:10];
    wire[19:0] imm20 = inst[24:5];
    wire[25:0] offs26 = {inst[9:0],inst[25:10]};
    
    always @(*) begin
        case(op)
            2'd0: imm32 = {{20{imm12[11]}},imm12};
            2'd1: imm32 = {{16{imm16[15]}},imm16};
            2'd2: imm32 = {imm20,12'b0};
            2'd3: imm32 = {{4{offs26[25]}},offs26,2'b00};
        endcase
    end 
endmodule

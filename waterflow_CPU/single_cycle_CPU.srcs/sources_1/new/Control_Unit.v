module Control_Unit(
    input[31:0]     inst,
    output          regWr,
    output          branch,
    output          RegDst,
    output reg[3:0] ALUctr,
    output          ALUSrc,
    output          MemWr,
    output          MemtoReg
    );
    
    wire add_w  = (inst[31:15] == 17'h00020);
    wire sub_w  = (inst[31:15] == 17'h00022);
    wire mul_w  = (inst[31:15] == 17'h00038);
    wire addi_w = (inst[31:22] == 10'h00a);
    wire ld_w   = (inst[31:22] == 10'h0a2);
    wire st_w   = (inst[31:22] == 10'h0a6);
    wire bne    = (inst[31:26] == 6'h17);
    
    assign regWr    = add_w|sub_w|mul_w|addi_w|ld_w;
    assign branch   = bne;
    assign RegDst   = st_w|bne;
    assign ALUSrc   = addi_w|ld_w;
    assign MemWr    = st_w;
    assign MemtoReg = ld_w;
    
    always @(*) begin
        case(1'b1)
            add_w:   ALUctr = 4'b0000;
            sub_w:   ALUctr = 4'b0001;
            mul_w:   ALUctr = 4'b0010;
            default: ALUctr = 4'b0000;
        endcase
    end
endmodule

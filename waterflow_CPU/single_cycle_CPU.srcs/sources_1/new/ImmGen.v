`include "CPU_def.vh"
module ImmGen(
    input     [31:0] inst,
    input     [3:0] ImmType,
    output reg[31:0] imm32
);
    
    wire [4:0]  ui5    = inst[14:10];
    wire [11:0] imm12  = inst[21:10];
    wire [13:0] imm14  = inst[23:10];
    wire [15:0] imm16  = inst[25:10];
    wire [19:0] imm20  = inst[24:5];
    wire [20:0] offs21 = {inst[4:0], inst[25:10]};
    wire [25:0] offs26 = {inst[9:0], inst[25:10]};
    
    always @(*) begin
        case(ImmType)
            `IMM_UI5:          imm32 = {27'b0, ui5};
            `IMM_SI12:         imm32 = {{20{imm12[11]}}, imm12};
            `IMM_UI12:         imm32 = {20'b0, imm12};
            `IMM_SI14_LSL2:    imm32 = {{16{imm14[13]}}, imm14, 2'b00};
            `IMM_SI16_LSL2:    imm32 = {{14{imm16[15]}}, imm16, 2'b00};
            `IMM_SI20_LSL2:    imm32 = {{10{imm20[19]}}, imm20, 2'b00};
            `IMM_SI20_LSL12:   imm32 = {imm20, 12'b0};
            `IMM_SI21_LSL2:    imm32 = {{9{offs21[20]}}, offs21, 2'b00};
            `IMM_SI26_LSL2:    imm32 = {{4{offs26[25]}}, offs26, 2'b00};
            default:           imm32 = 32'd0;  
        endcase
    end 
endmodule
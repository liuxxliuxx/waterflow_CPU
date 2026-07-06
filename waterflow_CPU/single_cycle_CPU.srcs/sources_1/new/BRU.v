module BRU(
    input[31:0]      pc,
    input[31:0]      imm32,
    input[31:0]      rdata1,
    input[2:0]       branch,
    input            ZF,
    input            SF,
    input            OF,
    input            CF,
    output[31:0]     branch_target,
    output reg       take_branch
    );
    
    wire[2:0] bne  = 3'b001;
    wire[2:0] blt  = 3'b010;
    wire[2:0] bl   = 3'b011;
    wire[2:0] jirl = 3'b100;
    
    wire[31:0] op_a = (branch == jirl) ? rdata1 : pc;
    
    adder add_bne(
        .A(op_a),
        .B(imm32),
        .cin(1'b0),
        .Sum(branch_target),
        .cout()
    );
    
    always @(*) begin
        case(branch)
            3'b001: begin
                take_branch   = ~ZF;
            end
            3'b010: begin
                take_branch   = SF^OF;
            end
            3'b011: begin
                take_branch   = 1'b1;
            end
            3'b100: begin
                take_branch   = 1'b1;
            end
            3'b101: begin
                take_branch   = (rdata1 == 32'd0);
            end
            3'b110: begin
                take_branch   = (~CF);
            end
            3'b111: begin
                take_branch   = ZF;
            end
            default: begin
                take_branch   = 1'b0;
            end
        endcase
    end
endmodule

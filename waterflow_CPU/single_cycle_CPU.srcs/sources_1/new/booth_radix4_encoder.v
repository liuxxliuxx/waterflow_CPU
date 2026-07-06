module booth_radix4_encoder (
    input  wire [31:0] A,
    input  wire [ 2:0] B_code,
    output wire [32:0] PP,
    output wire        neg
);
    reg [32:0] pp;
    reg        is_neg;

    always @(*) begin
        case(B_code)
            3'b000, 3'b111: begin pp = 33'd0;                is_neg = 1'b0; end // 0
            3'b001, 3'b010: begin pp = {A[31], A};           is_neg = 1'b0; end // +1A
            3'b011:         begin pp = {A, 1'b0};            is_neg = 1'b0; end // +2A
            3'b100:         begin pp = ~({A, 1'b0});         is_neg = 1'b1; end // -2A
            3'b101, 3'b110: begin pp = ~({A[31], A});        is_neg = 1'b1; end // -1A
            default:        begin pp = 33'd0;                is_neg = 1'b0; end
        endcase
    end

    assign PP  = pp;
    assign neg = is_neg;
endmodule
module diver(
    input         clk,
    input         rst,
    input         start,
    input         signed_mode,
    input  [31:0] A,
    input  [31:0] B,

    output        busy,
    output        ready,
    output [31:0] quotient,
    output [31:0] remainder,
    output reg error
);

    reg        busy_r;
    reg        ready_r;
    reg        prep_r;

    reg        quotient_neg_r;
    reg        remainder_neg_r;
    reg [5:0]  cnt_r;

    reg [31:0] dividend_r;
    reg [31:0] divisor_r;
    reg [31:0] quotient_r;
    reg [33:0] remainder_r;

    reg [31:0] quotient_out_r;
    reg [31:0] remainder_out_r;

    function [5:0] clz32;
        input [31:0] x;
        reg [15:0] v16;
        reg [7:0]  v8;
        reg [3:0]  v4;
        reg [1:0]  v2;
        begin
            if (x == 32'b0) begin
                clz32 = 6'd32;
            end
            else begin
                clz32 = 6'd0;

                if (x[31:16] == 16'b0) begin
                    clz32 = clz32 + 6'd16;
                    v16 = x[15:0];
                end
                else begin
                    v16 = x[31:16];
                end

                if (v16[15:8] == 8'b0) begin
                    clz32 = clz32 + 6'd8;
                    v8 = v16[7:0];
                end
                else begin
                    v8 = v16[15:8];
                end

                if (v8[7:4] == 4'b0) begin
                    clz32 = clz32 + 6'd4;
                    v4 = v8[3:0];
                end
                else begin
                    v4 = v8[7:4];
                end

                if (v4[3:2] == 2'b0) begin
                    clz32 = clz32 + 6'd2;
                    v2 = v4[1:0];
                end
                else begin
                    v2 = v4[3:2];
                end

                if (v2[1] == 1'b0) begin
                    clz32 = clz32 + 6'd1;
                end
            end
        end
    endfunction

    wire [31:0] abs_a = (signed_mode && A[31]) ? (~A + 32'd1) : A;
    wire [31:0] abs_b = (signed_mode && B[31]) ? (~B + 32'd1) : B;

    wire quotient_neg_w  = signed_mode && (A[31] ^ B[31]);
    wire remainder_neg_w = signed_mode && A[31];

    wire [5:0] clz_a = clz32(dividend_r);
    wire [5:0] clz_b = clz32(divisor_r);

    wire [5:0] bit_len_a = 6'd32 - clz_a;
    wire [5:0] bit_len_b = 6'd32 - clz_b;

    wire [5:0] q_bits = bit_len_a - bit_len_b + 6'd1;

    wire [5:0] group_cnt = (q_bits + 6'd1) >> 1;

    wire [5:0] process_bits = {group_cnt[4:0], 1'b0};

    wire [5:0] dividend_shift = 6'd32 - process_bits;

    wire [31:0] prep_dividend = dividend_r << dividend_shift;

    wire [31:0] prep_remainder_low =
        (process_bits == 6'd32) ? 32'd0 : (dividend_r >> process_bits);

    wire [33:0] prep_remainder = {2'b00, prep_remainder_low};

    wire [33:0] shifted_remainder = {remainder_r[31:0], dividend_r[31:30]};

    wire [33:0] divisor_1x = {2'b00, divisor_r};
    wire [33:0] divisor_2x = {1'b0, divisor_r, 1'b0};
    wire [33:0] divisor_3x = divisor_2x + divisor_1x;

    wire [1:0] q_digit =
        (shifted_remainder >= divisor_3x) ? 2'd3 :
        (shifted_remainder >= divisor_2x) ? 2'd2 :
        (shifted_remainder >= divisor_1x) ? 2'd1 :
                                            2'd0;

    wire [33:0] subtract_value =
        (q_digit == 2'd3) ? divisor_3x :
        (q_digit == 2'd2) ? divisor_2x :
        (q_digit == 2'd1) ? divisor_1x :
                            34'd0;

    wire [33:0] next_remainder = shifted_remainder - subtract_value;

    wire [31:0] next_quotient = {quotient_r[29:0], q_digit};

    wire [31:0] next_dividend = {dividend_r[29:0], 2'b00};

    wire [31:0] fixed_quotient =
        quotient_neg_r ? (~next_quotient + 32'd1) : next_quotient;

    wire [31:0] fixed_remainder =
        remainder_neg_r ? (~next_remainder[31:0] + 32'd1) : next_remainder[31:0];

    assign busy      = busy_r;
    assign ready     = ready_r;
    assign quotient  = quotient_out_r;
    assign remainder = remainder_out_r;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            busy_r          <= 1'b0;
            ready_r         <= 1'b0;
            prep_r          <= 1'b0;

            quotient_neg_r  <= 1'b0;
            remainder_neg_r <= 1'b0;
            cnt_r           <= 6'b0;

            dividend_r      <= 32'b0;
            divisor_r       <= 32'b0;
            quotient_r      <= 32'b0;
            remainder_r     <= 34'b0;

            quotient_out_r  <= 32'b0;
            remainder_out_r <= 32'b0;
            error           <= 1'b0;
        end
        else begin
            ready_r <= 1'b0;
            if (start && !busy_r) begin
                error           <= 1'b0;
                quotient_neg_r  <= quotient_neg_w;
                remainder_neg_r <= remainder_neg_w;
                dividend_r      <= abs_a;
                divisor_r       <= abs_b;
                quotient_r      <= 32'b0;
                remainder_r     <= 34'b0;
                cnt_r           <= 6'b0;
                prep_r          <= 1'b0;
                if (B == 32'b0) begin
                    busy_r          <= 1'b0;
                    ready_r         <= 1'b1;
                    quotient_out_r  <= 32'b0;
                    remainder_out_r <= 32'b0;
                    error           <= 1'b1;
                end
                else if (abs_a == 32'd0) begin
                    busy_r          <= 1'b0;
                    ready_r         <= 1'b1;
                    quotient_out_r  <= 32'b0;
                    remainder_out_r <= 32'b0;
                end
                else if (abs_b == 32'd1) begin
                    busy_r          <= 1'b0;
                    ready_r         <= 1'b1;
                    quotient_out_r  <= quotient_neg_w ? (~abs_a + 32'd1) : abs_a;
                    remainder_out_r <= 32'b0;
                end
                else if (abs_a < abs_b) begin
                    busy_r          <= 1'b0;
                    ready_r         <= 1'b1;
                    quotient_out_r  <= 32'b0;
                    remainder_out_r <= A;
                end
                else if (abs_a == abs_b) begin
                    busy_r          <= 1'b0;
                    ready_r         <= 1'b1;
                    quotient_out_r  <= quotient_neg_w ? 32'hFFFF_FFFF : 32'd1;
                    remainder_out_r <= 32'b0;
                end

                else begin
                    busy_r <= 1'b1;
                    prep_r <= 1'b1;
                end
            end
            else if (busy_r && prep_r) begin
                prep_r      <= 1'b0;

                dividend_r  <= prep_dividend;
                remainder_r <= prep_remainder;

                quotient_r  <= 32'b0;
                cnt_r       <= group_cnt;
            end
            else if (busy_r) begin
                dividend_r  <= next_dividend;
                quotient_r  <= next_quotient;
                remainder_r <= next_remainder;
                if (cnt_r == 6'd1) begin
                    busy_r          <= 1'b0;
                    ready_r         <= 1'b1;
                    prep_r          <= 1'b0;
                    cnt_r           <= 6'b0;
                    quotient_out_r  <= fixed_quotient;
                    remainder_out_r <= fixed_remainder;
                end
                else begin
                    cnt_r <= cnt_r - 6'd1;
                end
            end
        end
    end
endmodule
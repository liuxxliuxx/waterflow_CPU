module fp_mul_s(
    input         clk,
    input         rst,
    input         start,
    input  [31:0] A,
    input  [31:0] B,

    output        busy,
    output        ready,
    output [31:0] R,
    output        exc_of,
    output        exc_uf
);

    wire        sign_res_w = A[31] ^ B[31];
    wire [7:0]  exp_a_w    = A[30:23];
    wire [7:0]  exp_b_w    = B[30:23];
    wire [22:0] frac_a_w   = A[22:0];
    wire [22:0] frac_b_w   = B[22:0];

    wire a_nan  = (exp_a_w == 8'hff) && (frac_a_w != 23'b0);
    wire b_nan  = (exp_b_w == 8'hff) && (frac_b_w != 23'b0);
    wire a_inf  = (exp_a_w == 8'hff) && (frac_a_w == 23'b0);
    wire b_inf  = (exp_b_w == 8'hff) && (frac_b_w == 23'b0);
    wire a_zero = (A[30:0] == 31'b0);
    wire b_zero = (B[30:0] == 31'b0);

    wire [7:0] expa_eff_w =
        (exp_a_w == 8'b0) ? 8'd1 : exp_a_w;

    wire [7:0] expb_eff_w =
        (exp_b_w == 8'b0) ? 8'd1 : exp_b_w;

    wire [23:0] mana_w =
        (exp_a_w == 8'b0) ? {1'b0, frac_a_w} :
                            {1'b1, frac_a_w};

    wire [23:0] manb_w =
        (exp_b_w == 8'b0) ? {1'b0, frac_b_w} :
                            {1'b1, frac_b_w};

    reg [31:0] special_result;

    always @(*) begin
        if (a_nan || b_nan) begin
            special_result = 32'h7fc0_0000;
        end
        else if ((a_inf && b_zero) || (b_inf && a_zero)) begin
            special_result = 32'h7fc0_0000;
        end
        else if (a_inf || b_inf) begin
            special_result = {sign_res_w, 8'hff, 23'b0};
        end
        else begin
            special_result = {sign_res_w, 31'b0};
        end
    end

    wire special_case =
        a_nan ||
        b_nan ||
        (a_inf && b_zero) ||
        (b_inf && a_zero) ||
        a_inf ||
        b_inf ||
        a_zero ||
        b_zero;

    wire normal_start = start && !special_case;

    reg         mul_valid_s0;
    reg         mul_valid_s1;
    reg         mul_valid_s2;
    reg         mul_ready;
    (* use_dsp = "yes" *) reg [47:0] mant_product_s0;
    reg [47:0] mant_product_s1;
    reg [47:0] mant_product_s2;
    reg [47:0] mant_product_full;

    wire mul_busy = mul_valid_s0 || mul_valid_s1 || mul_valid_s2;

    always @(posedge clk) begin
        if (normal_start)
            mant_product_s0 <= mana_w * manb_w;
        if (mul_valid_s0)
            mant_product_s1 <= mant_product_s0;
        if (mul_valid_s1)
            mant_product_s2 <= mant_product_s1;
        if (mul_valid_s2)
            mant_product_full <= mant_product_s2;
    end

    reg               special_ready_r;
    reg [31:0]        special_result_r;
    reg               sign_res_r;
    reg signed [10:0] exp_res_r;

    wire [31:0] normal_result;
    wire        finish_exc_of;
    wire        finish_exc_uf;
    wire        finish_ready;

    fp_mul_s_finish u_finish(
        .clk      (clk),
        .rst      (rst),
        .start    (mul_ready),
        .sign_res (sign_res_r),
        .exp_base (exp_res_r),
        .product  (mant_product_full),
        .ready    (finish_ready),
        .R        (normal_result),
        .exc_of   (finish_exc_of),
        .exc_uf   (finish_exc_uf)
    );

    assign busy   = mul_busy || mul_ready;
    assign ready  = special_ready_r || finish_ready;
    assign R      = special_ready_r ? special_result_r : normal_result;
    assign exc_of = special_ready_r ? 1'b0 : finish_exc_of;
    assign exc_uf = special_ready_r ? 1'b0 : finish_exc_uf;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            special_ready_r  <= 1'b0;
            special_result_r <= 32'b0;
            sign_res_r       <= 1'b0;
            exp_res_r        <= 11'sd0;
            mul_valid_s0     <= 1'b0;
            mul_valid_s1     <= 1'b0;
            mul_valid_s2     <= 1'b0;
            mul_ready        <= 1'b0;
        end
        else begin
            special_ready_r <= 1'b0;
            mul_valid_s0    <= normal_start;
            mul_valid_s1    <= mul_valid_s0;
            mul_valid_s2    <= mul_valid_s1;
            mul_ready       <= mul_valid_s2;

            if (start) begin
                if (special_case) begin
                    special_ready_r  <= 1'b1;
                    special_result_r <= special_result;
                end
                else begin
                    sign_res_r <= sign_res_w;
                    exp_res_r  <=
                        $signed({3'b0, expa_eff_w}) +
                        $signed({3'b0, expb_eff_w}) -
                        11'sd127;
                end
            end
        end
    end

endmodule


module fp_mul_s_finish(
    input               clk,
    input               rst,
    input               start,
    input               sign_res,
    input signed [10:0] exp_base,
    input        [47:0] product,
    output reg          ready,
    output reg   [31:0] R,
    output reg          exc_of,
    output reg          exc_uf
);

    reg [47:0] product_norm_w;
    reg signed [10:0] exp_norm_w;
    reg [26:0] mant_norm_w;
    reg        product_zero_w;
    reg [5:0]  shift_num_w;

    reg               sign_norm_r;
    reg signed [10:0] exp_norm_r;
    reg        [26:0] mant_norm_r;
    reg               product_zero_r;

    reg signed [10:0] exp_round;
    reg [24:0] rounded;
    reg        round_inc;

    function [5:0] clz48;
        input [47:0] x;
        reg [31:0] v32;
        reg [15:0] v16;
        reg [7:0]  v8;
        reg [3:0]  v4;
        reg [1:0]  v2;
        begin
            if (x == 48'b0) begin
                clz48 = 6'd48;
            end
            else begin
                clz48 = 6'd0;

                if (x[47:32] == 16'b0) begin
                    clz48 = clz48 + 6'd16;
                    v32 = x[31:0];
                end
                else begin
                    v32 = {x[47:32], 16'b0};
                end

                if (v32[31:16] == 16'b0) begin
                    clz48 = clz48 + 6'd16;
                    v16 = v32[15:0];
                end
                else begin
                    v16 = v32[31:16];
                end

                if (v16[15:8] == 8'b0) begin
                    clz48 = clz48 + 6'd8;
                    v8 = v16[7:0];
                end
                else begin
                    v8 = v16[15:8];
                end

                if (v8[7:4] == 4'b0) begin
                    clz48 = clz48 + 6'd4;
                    v4 = v8[3:0];
                end
                else begin
                    v4 = v8[7:4];
                end

                if (v4[3:2] == 2'b0) begin
                    clz48 = clz48 + 6'd2;
                    v2 = v4[1:0];
                end
                else begin
                    v2 = v4[3:2];
                end

                if (v2[1] == 1'b0) begin
                    clz48 = clz48 + 6'd1;
                end
            end
        end
    endfunction

    // Stage 1: normalize the multiplier product and adjust the exponent.
    always @(*) begin
        product_norm_w = product;
        exp_norm_w     = exp_base;
        mant_norm_w    = 27'b0;
        product_zero_w = (product == 48'b0);
        shift_num_w    = 6'd0;

        if (product != 48'b0) begin
            if (product[47]) begin
                mant_norm_w = {
                    product[47:24],
                    product[23],
                    product[22],
                    |product[21:0]
                };

                exp_norm_w = exp_base + 11'sd1;
            end
            else begin
                shift_num_w    = clz48(product) - 6'd1;
                product_norm_w = product << shift_num_w;
                exp_norm_w     = exp_base - $signed({5'b0, shift_num_w});

                mant_norm_w = {
                    product_norm_w[46:23],
                    product_norm_w[22],
                    product_norm_w[21],
                    |product_norm_w[20:0]
                };
            end
        end
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            ready          <= 1'b0;
            sign_norm_r    <= 1'b0;
            exp_norm_r     <= 11'sd0;
            mant_norm_r    <= 27'b0;
            product_zero_r <= 1'b1;
        end
        else begin
            ready <= start;

            if (start) begin
                sign_norm_r    <= sign_res;
                exp_norm_r     <= exp_norm_w;
                mant_norm_r    <= mant_norm_w;
                product_zero_r <= product_zero_w;
            end
        end
    end

    // Stage 2: round, check exponent range, and pack the IEEE-754 result.
    always @(*) begin
        exp_round = exp_norm_r;
        rounded   = 25'b0;
        round_inc = 1'b0;
        R         = 32'b0;
        exc_of    = 1'b0;
        exc_uf    = 1'b0;

        if (product_zero_r) begin
            R = {sign_norm_r, 31'b0};
        end
        else if (exp_norm_r <= 0) begin
            R      = {sign_norm_r, 31'b0};
            exc_uf = 1'b1;
        end
        else begin
            round_inc =
                mant_norm_r[2] &
                (mant_norm_r[1] | mant_norm_r[0] | mant_norm_r[3]);

            rounded = {1'b0, mant_norm_r[26:3]} + round_inc;

            if (rounded[24]) begin
                rounded   = rounded >> 1;
                exp_round = exp_norm_r + 11'sd1;
            end

            if (exp_round >= 11'sd255) begin
                R      = {sign_norm_r, 8'hff, 23'b0};
                exc_of = 1'b1;
            end
            else begin
                R = {
                    sign_norm_r,
                    exp_round[7:0],
                    rounded[22:0]
                };
            end
        end
    end

endmodule

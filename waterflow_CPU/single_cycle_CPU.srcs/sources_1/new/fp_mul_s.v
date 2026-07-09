module fp_mul_s(
    input         clk,
    input         rst,
    input         start,
    input  [31:0] A,
    input  [31:0] B,

    output        busy,
    output        ready,
    output [31:0] R
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

    wire [7:0]  expa_eff_w = (exp_a_w == 8'b0) ? 8'd1 : exp_a_w;
    wire [7:0]  expb_eff_w = (exp_b_w == 8'b0) ? 8'd1 : exp_b_w;
    wire [23:0] mana_w     = (exp_a_w == 8'b0) ? {1'b0, frac_a_w} : {1'b1, frac_a_w};
    wire [23:0] manb_w     = (exp_b_w == 8'b0) ? {1'b0, frac_b_w} : {1'b1, frac_b_w};

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

    wire special_case = a_nan || b_nan || (a_inf && b_zero) ||
                        (b_inf && a_zero) || a_inf || b_inf ||
                        a_zero || b_zero;
    wire normal_start = start && !special_case;

    wire        mul_busy;
    wire        mul_ready;
    wire [63:0] mant_product_full;

    booth_wallace u_mant_mul(
        .clk     (clk),
        .rst     (rst),
        .start   (normal_start),
        .A       ({8'b0, mana_w}),
        .B       ({8'b0, manb_w}),
        .busy    (mul_busy),
        .ready   (mul_ready),
        .Product (mant_product_full)
    );

    reg        special_ready_r;
    reg [31:0] special_result_r;
    reg        sign_res_r;
    reg signed [10:0] exp_res_r;

    wire [31:0] normal_result;
    fp_mul_s_finish u_finish(
        .sign_res (sign_res_r),
        .exp_base (exp_res_r),
        .product  (mant_product_full[47:0]),
        .R        (normal_result)
    );

    assign busy  = mul_busy;
    assign ready = special_ready_r || mul_ready;
    assign R     = special_ready_r ? special_result_r : normal_result;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            special_ready_r <= 1'b0;
            special_result_r <= 32'b0;
            sign_res_r      <= 1'b0;
            exp_res_r       <= 11'sd0;
        end
        else begin
            special_ready_r <= 1'b0;

            if (start) begin
                if (special_case) begin
                    special_ready_r <= 1'b1;
                    special_result_r <= special_result;
                end
                else begin
                    sign_res_r <= sign_res_w;
                    exp_res_r  <= $signed({3'b0, expa_eff_w}) +
                                  $signed({3'b0, expb_eff_w}) -
                                  11'sd127;
                end
            end
        end
    end

endmodule


module fp_mul_s_finish(
    input             sign_res,
    input signed [10:0] exp_base,
    input      [47:0] product,
    output reg [31:0] R
);

    reg [47:0] product_norm;
    reg signed [10:0] exp_res;
    reg [26:0] mant_res;
    reg [24:0] rounded;
    reg        round_inc;

    integer i;

    always @(*) begin
        exp_res = exp_base;
        product_norm = product;
        mant_res = 27'b0;
        rounded = 25'b0;
        round_inc = 1'b0;
        R = 32'b0;

        if (product[47]) begin
            mant_res = {product[47:24], product[23], product[22], |product[21:0]};
            exp_res  = exp_res + 11'sd1;
        end
        else begin
            for (i = 0; i < 48; i = i + 1) begin
                if (product_norm[46] == 1'b0 && product_norm != 48'b0 && exp_res > 0) begin
                    product_norm = product_norm << 1;
                    exp_res      = exp_res - 11'sd1;
                end
            end

            mant_res = {
                product_norm[46:23],
                product_norm[22],
                product_norm[21],
                |product_norm[20:0]
            };
        end

        if (exp_res <= 0) begin
            R = {sign_res, 31'b0};
        end
        else begin
            round_inc = mant_res[2] & (mant_res[1] | mant_res[0] | mant_res[3]);
            rounded   = {1'b0, mant_res[26:3]} + round_inc;

            if (rounded[24]) begin
                rounded = rounded >> 1;
                exp_res = exp_res + 11'sd1;
            end

            if (exp_res >= 255) begin
                R = {sign_res, 8'hff, 23'b0};
            end
            else begin
                R = {sign_res, exp_res[7:0], rounded[22:0]};
            end
        end
    end

endmodule

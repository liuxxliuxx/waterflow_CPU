module fp_mul_s(
    input  [31:0] A,
    input  [31:0] B,
    output reg [31:0] R
);

    reg        sign_a;
    reg        sign_b;
    reg        sign_res;

    reg [7:0]  exp_a;
    reg [7:0]  exp_b;
    reg [22:0] frac_a;
    reg [22:0] frac_b;

    reg [7:0]  expa_eff;
    reg [7:0]  expb_eff;

    reg [23:0] mana;
    reg [23:0] manb;

    reg [47:0] product;
    reg [47:0] product_norm;

    reg signed [10:0] exp_res;
    reg [26:0] mant_res;

    reg [24:0] rounded;
    reg        round_inc;

    integer i;

    always @(*) begin
        sign_a = A[31];
        sign_b = B[31];
        sign_res = sign_a ^ sign_b;

        exp_a  = A[30:23];
        exp_b  = B[30:23];
        frac_a = A[22:0];
        frac_b = B[22:0];

        R = 32'b0;

        // NaN
        if ((exp_a == 8'hff && frac_a != 0) ||
            (exp_b == 8'hff && frac_b != 0)) begin
            R = 32'h7fc0_0000;
        end

        // Inf * 0 = NaN
        else if (((exp_a == 8'hff && frac_a == 0) && B[30:0] == 0) ||
                 ((exp_b == 8'hff && frac_b == 0) && A[30:0] == 0)) begin
            R = 32'h7fc0_0000;
        end

        // Inf * normal = Inf
        else if ((exp_a == 8'hff && frac_a == 0) ||
                 (exp_b == 8'hff && frac_b == 0)) begin
            R = {sign_res, 8'hff, 23'b0};
        end

        // zero
        else if (A[30:0] == 0 || B[30:0] == 0) begin
            R = {sign_res, 31'b0};
        end

        else begin
            expa_eff = (exp_a == 8'b0) ? 8'd1 : exp_a;
            expb_eff = (exp_b == 8'b0) ? 8'd1 : exp_b;

            mana = (exp_a == 8'b0) ? {1'b0, frac_a} : {1'b1, frac_a};
            manb = (exp_b == 8'b0) ? {1'b0, frac_b} : {1'b1, frac_b};

            product = mana * manb;

            exp_res = $signed({3'b0, expa_eff}) +
                      $signed({3'b0, expb_eff}) -
                      11'sd127;

            if (product[47]) begin
                mant_res = {product[47:24], product[23], product[22], |product[21:0]};
                exp_res  = exp_res + 11'sd1;
            end
            else begin
                product_norm = product;

                for (i = 0; i < 48; i = i + 1) begin
                    if (product_norm[46] == 1'b0 && product_norm != 0 && exp_res > 0) begin
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
    end

endmodule
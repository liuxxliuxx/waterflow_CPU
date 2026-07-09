module fp_add_s(
    input  [31:0] A,
    input  [31:0] B,
    output reg [31:0] R
);

    reg        sign_a;
    reg        sign_b;
    reg [7:0]  exp_a;
    reg [7:0]  exp_b;
    reg [22:0] frac_a;
    reg [22:0] frac_b;

    reg [7:0]  expa_eff;
    reg [7:0]  expb_eff;
    reg [23:0] mana;
    reg [23:0] manb;

    reg [26:0] mant_a_ext;
    reg [26:0] mant_b_ext;

    reg [26:0] mant_big;
    reg [26:0] mant_small;
    reg        sign_big;
    reg        sign_small;
    reg [8:0]  exp_big;

    reg [27:0] mant_sum;
    reg [26:0] mant_res;
    reg [8:0]  exp_res;
    reg        sign_res;

    reg [24:0] rounded;
    reg        round_inc;

    integer i;

    function [26:0] shift_right_sticky;
        input [26:0] data;
        input [7:0]  shamt;
        integer j;
        reg sticky;
        begin
            if (shamt == 0) begin
                shift_right_sticky = data;
            end
            else if (shamt >= 27) begin
                shift_right_sticky = {26'b0, |data};
            end
            else begin
                sticky = 1'b0;
                for (j = 0; j < 27; j = j + 1) begin
                    if (j < shamt)
                        sticky = sticky | data[j];
                end

                shift_right_sticky = data >> shamt;
                shift_right_sticky[0] = shift_right_sticky[0] | sticky;
            end
        end
    endfunction

    always @(*) begin
        sign_a = A[31];
        sign_b = B[31];
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

        // Inf + Inf
        else if ((exp_a == 8'hff && frac_a == 0) &&
                 (exp_b == 8'hff && frac_b == 0)) begin
            if (sign_a != sign_b)
                R = 32'h7fc0_0000;
            else
                R = {sign_a, 8'hff, 23'b0};
        end

        // A is Inf
        else if (exp_a == 8'hff && frac_a == 0) begin
            R = {sign_a, 8'hff, 23'b0};
        end

        // B is Inf
        else if (exp_b == 8'hff && frac_b == 0) begin
            R = {sign_b, 8'hff, 23'b0};
        end

        // both zero
        else if (A[30:0] == 31'b0 && B[30:0] == 31'b0) begin
            R = {(sign_a & sign_b), 31'b0};
        end

        else begin
            expa_eff = (exp_a == 8'b0) ? 8'd1 : exp_a;
            expb_eff = (exp_b == 8'b0) ? 8'd1 : exp_b;

            mana = (exp_a == 8'b0) ? {1'b0, frac_a} : {1'b1, frac_a};
            manb = (exp_b == 8'b0) ? {1'b0, frac_b} : {1'b1, frac_b};

            mant_a_ext = {mana, 3'b000};
            mant_b_ext = {manb, 3'b000};

            if ((expa_eff > expb_eff) ||
                ((expa_eff == expb_eff) && (mana >= manb))) begin
                mant_big   = mant_a_ext;
                mant_small = shift_right_sticky(mant_b_ext, expa_eff - expb_eff);
                sign_big   = sign_a;
                sign_small = sign_b;
                exp_big    = {1'b0, expa_eff};
            end
            else begin
                mant_big   = mant_b_ext;
                mant_small = shift_right_sticky(mant_a_ext, expb_eff - expa_eff);
                sign_big   = sign_b;
                sign_small = sign_a;
                exp_big    = {1'b0, expb_eff};
            end

            if (sign_big == sign_small) begin
                mant_sum = {1'b0, mant_big} + {1'b0, mant_small};
                sign_res = sign_big;
                exp_res  = exp_big;

                if (mant_sum[27]) begin
                    mant_res    = mant_sum[27:1];
                    mant_res[0] = mant_res[0] | mant_sum[0];
                    exp_res     = exp_big + 9'd1;
                end
                else begin
                    mant_res = mant_sum[26:0];
                end
            end
            else begin
                sign_res = sign_big;
                exp_res  = exp_big;

                if (mant_big == mant_small) begin
                    mant_res = 27'b0;
                    exp_res  = 9'b0;
                    sign_res = 1'b0;
                end
                else begin
                    mant_res = mant_big - mant_small;

                    for (i = 0; i < 27; i = i + 1) begin
                        if (mant_res[26] == 1'b0 && exp_res > 9'd1 && mant_res != 0) begin
                            mant_res = mant_res << 1;
                            exp_res  = exp_res - 9'd1;
                        end
                    end
                end
            end

            if (mant_res == 0) begin
                R = 32'b0;
            end
            else begin
                round_inc = mant_res[2] & (mant_res[1] | mant_res[0] | mant_res[3]);
                rounded   = {1'b0, mant_res[26:3]} + round_inc;

                if (rounded[24]) begin
                    rounded = rounded >> 1;
                    exp_res = exp_res + 9'd1;
                end

                if (exp_res >= 9'd255) begin
                    R = {sign_res, 8'hff, 23'b0};
                end
                else if (exp_res == 9'd1 && rounded[23] == 1'b0) begin
                    R = {sign_res, 8'b0, rounded[22:0]};
                end
                else begin
                    R = {sign_res, exp_res[7:0], rounded[22:0]};
                end
            end
        end
    end

endmodule
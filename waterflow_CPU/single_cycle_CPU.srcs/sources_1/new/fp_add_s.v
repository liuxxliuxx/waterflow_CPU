`timescale 1ns / 1ps

module fp_add_s(
    input         clk,
    input         rst,
    input         start,
    input         sub,
    input  [31:0] A,
    input  [31:0] B,

    output        busy,
    output        ready,
    output reg [31:0] R,
    output reg        exc_of,
    output reg        exc_uf
);

    localparam S_IDLE      = 3'd0;
    localparam S_ALIGN     = 3'd1;
    localparam S_ADD_SUB   = 3'd2;
    localparam S_NORMALIZE = 3'd3;
    localparam S_ROUND     = 3'd4;
    localparam S_PACK      = 3'd5;
    localparam S_DONE      = 3'd6;

    reg [2:0] state;

    reg [31:0] a_r;
    reg [31:0] b_eff_r;

    reg [26:0] mant_big_r;
    reg [26:0] mant_small_r;
    reg        sign_big_r;
    reg        sign_small_r;
    reg [8:0]  exp_big_r;

    reg [26:0] mant_work_r;
    reg [8:0]  exp_res_r;
    reg        sign_res_r;
    reg [24:0] rounded_r;

    wire        sign_a_w = a_r[31];
    wire        sign_b_w = b_eff_r[31];
    wire [7:0]  exp_a_w  = a_r[30:23];
    wire [7:0]  exp_b_w  = b_eff_r[30:23];
    wire [22:0] frac_a_w = a_r[22:0];
    wire [22:0] frac_b_w = b_eff_r[22:0];

    wire [7:0] expa_eff_w = (exp_a_w == 8'b0) ? 8'd1 : exp_a_w;
    wire [7:0] expb_eff_w = (exp_b_w == 8'b0) ? 8'd1 : exp_b_w;
    wire [23:0] mana_w = (exp_a_w == 8'b0) ?
                           {1'b0, frac_a_w} : {1'b1, frac_a_w};
    wire [23:0] manb_w = (exp_b_w == 8'b0) ?
                           {1'b0, frac_b_w} : {1'b1, frac_b_w};
    wire [26:0] mant_a_ext_w = {mana_w, 3'b000};
    wire [26:0] mant_b_ext_w = {manb_w, 3'b000};

    wire a_nan_w  = (exp_a_w == 8'hff) && (frac_a_w != 23'b0);
    wire b_nan_w  = (exp_b_w == 8'hff) && (frac_b_w != 23'b0);
    wire a_inf_w  = (exp_a_w == 8'hff) && (frac_a_w == 23'b0);
    wire b_inf_w  = (exp_b_w == 8'hff) && (frac_b_w == 23'b0);
    wire a_zero_w = (a_r[30:0] == 31'b0);
    wire b_zero_w = (b_eff_r[30:0] == 31'b0);

    wire a_is_big_w =
        (expa_eff_w > expb_eff_w) ||
        ((expa_eff_w == expb_eff_w) && (mana_w >= manb_w));

    wire [27:0] mant_add_w =
        {1'b0, mant_big_r} + {1'b0, mant_small_r};
    wire [24:0] rounded_w =
        {1'b0, mant_work_r[26:3]} +
        (mant_work_r[2] &
         (mant_work_r[1] | mant_work_r[0] | mant_work_r[3]));

    assign busy  = (state != S_IDLE) && (state != S_DONE);
    assign ready = (state == S_DONE);

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
                shift_right_sticky[0] =
                    shift_right_sticky[0] | sticky;
            end
        end
    endfunction

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            state        <= S_IDLE;
            a_r          <= 32'b0;
            b_eff_r      <= 32'b0;
            mant_big_r   <= 27'b0;
            mant_small_r <= 27'b0;
            sign_big_r   <= 1'b0;
            sign_small_r <= 1'b0;
            exp_big_r    <= 9'b0;
            mant_work_r  <= 27'b0;
            exp_res_r    <= 9'b0;
            sign_res_r   <= 1'b0;
            rounded_r    <= 25'b0;
            R            <= 32'b0;
            exc_of       <= 1'b0;
            exc_uf       <= 1'b0;
        end
        else if (start) begin
            // A new start supersedes an in-flight add/sub.  This lets the
            // existing EXU recover from a pipeline flush without adding a
            // cancellation signal to the FPU interface.
            a_r          <= A;
            b_eff_r      <= sub ? {~B[31], B[30:0]} : B;
            state        <= S_ALIGN;
            mant_big_r   <= 27'b0;
            mant_small_r <= 27'b0;
            mant_work_r  <= 27'b0;
            rounded_r    <= 25'b0;
            R            <= 32'b0;
            exc_of       <= 1'b0;
            exc_uf       <= 1'b0;
        end
        else begin
            case (state)
                S_IDLE: begin
                    state <= S_IDLE;
                end

                S_ALIGN: begin
                    exc_of <= 1'b0;
                    exc_uf <= 1'b0;

                    if (a_nan_w || b_nan_w) begin
                        R     <= 32'h7fc0_0000;
                        state <= S_DONE;
                    end
                    else if (a_inf_w && b_inf_w) begin
                        if (sign_a_w != sign_b_w)
                            R <= 32'h7fc0_0000;
                        else
                            R <= {sign_a_w, 8'hff, 23'b0};
                        state <= S_DONE;
                    end
                    else if (a_inf_w) begin
                        R     <= {sign_a_w, 8'hff, 23'b0};
                        state <= S_DONE;
                    end
                    else if (b_inf_w) begin
                        R     <= {sign_b_w, 8'hff, 23'b0};
                        state <= S_DONE;
                    end
                    else if (a_zero_w && b_zero_w) begin
                        R     <= {(sign_a_w & sign_b_w), 31'b0};
                        state <= S_DONE;
                    end
                    else begin
                        if (a_is_big_w) begin
                            mant_big_r   <= mant_a_ext_w;
                            mant_small_r <= shift_right_sticky(
                                mant_b_ext_w,
                                expa_eff_w - expb_eff_w
                            );
                            sign_big_r   <= sign_a_w;
                            sign_small_r <= sign_b_w;
                            exp_big_r    <= {1'b0, expa_eff_w};
                        end
                        else begin
                            mant_big_r   <= mant_b_ext_w;
                            mant_small_r <= shift_right_sticky(
                                mant_a_ext_w,
                                expb_eff_w - expa_eff_w
                            );
                            sign_big_r   <= sign_b_w;
                            sign_small_r <= sign_a_w;
                            exp_big_r    <= {1'b0, expb_eff_w};
                        end
                        state <= S_ADD_SUB;
                    end
                end

                S_ADD_SUB: begin
                    sign_res_r <= sign_big_r;

                    if (sign_big_r == sign_small_r) begin
                        if (mant_add_w[27]) begin
                            mant_work_r    <= mant_add_w[27:1];
                            mant_work_r[0] <=
                                mant_add_w[1] | mant_add_w[0];
                            exp_res_r <= exp_big_r + 9'd1;
                        end
                        else begin
                            mant_work_r <= mant_add_w[26:0];
                            exp_res_r   <= exp_big_r;
                        end
                        state <= S_ROUND;
                    end
                    else if (mant_big_r == mant_small_r) begin
                        mant_work_r <= 27'b0;
                        exp_res_r   <= 9'b0;
                        sign_res_r  <= 1'b0;
                        R           <= 32'b0;
                        state       <= S_DONE;
                    end
                    else begin
                        mant_work_r <= mant_big_r - mant_small_r;
                        exp_res_r   <= exp_big_r;
                        state       <= S_NORMALIZE;
                    end
                end

                S_NORMALIZE: begin
                    if (mant_work_r == 27'b0) begin
                        R          <= 32'b0;
                        sign_res_r <= 1'b0;
                        exp_res_r  <= 9'b0;
                        state      <= S_DONE;
                    end
                    else if (!mant_work_r[26] && (exp_res_r > 9'd1)) begin
                        mant_work_r <= mant_work_r << 1;
                        exp_res_r   <= exp_res_r - 9'd1;
                    end
                    else begin
                        state <= S_ROUND;
                    end
                end

                S_ROUND: begin
                    if (mant_work_r == 27'b0) begin
                        R     <= 32'b0;
                        state <= S_DONE;
                    end
                    else begin
                        if (rounded_w[24]) begin
                            rounded_r <= rounded_w >> 1;
                            exp_res_r <= exp_res_r + 9'd1;
                        end
                        else begin
                            rounded_r <= rounded_w;
                        end
                        state <= S_PACK;
                    end
                end

                S_PACK: begin
                    if (exp_res_r >= 9'd255) begin
                        R      <= {sign_res_r, 8'hff, 23'b0};
                        exc_of <= 1'b1;
                    end
                    else if ((exp_res_r == 9'd1) && !rounded_r[23]) begin
                        R      <= {sign_res_r, 8'b0, rounded_r[22:0]};
                        exc_uf <= 1'b1;
                    end
                    else begin
                        R <= {sign_res_r, exp_res_r[7:0], rounded_r[22:0]};
                    end
                    state <= S_DONE;
                end

                S_DONE: begin
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule

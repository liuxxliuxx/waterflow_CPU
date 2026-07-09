module booth_wallace(
    input         clk,
    input         rst,
    input         start,
    input  [31:0] A,
    input  [31:0] B,

    output        busy,
    output        ready,
    output reg [63:0] Product
    );

    reg [31:0] a_r;
    reg [31:0] b_r;

    wire [32:0] B_ext = {b_r, 1'b0};

    wire [32:0] pp_raw [0:15];
    wire [15:0] is_neg;
    wire [63:0] pp_aligned [0:15];

    // Stage 1: Booth encode and the first two CSA levels.
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_booth
            booth_radix4_encoder u_booth (
                .A      (a_r),
                .B_code (B_ext[2*i+2 : 2*i]),
                .PP     (pp_raw[i]),
                .neg    (is_neg[i])
            );

            assign pp_aligned[i] = {{31{pp_raw[i][32]}}, pp_raw[i]} << (2*i);
        end
    endgenerate

    wire [63:0] comp_row;
    assign comp_row = {
        32'd0,
        1'b0, is_neg[15], 1'b0, is_neg[14], 1'b0, is_neg[13], 1'b0, is_neg[12],
        1'b0, is_neg[11], 1'b0, is_neg[10], 1'b0, is_neg[9],  1'b0, is_neg[8],
        1'b0, is_neg[7],  1'b0, is_neg[6],  1'b0, is_neg[5],  1'b0, is_neg[4],
        1'b0, is_neg[3],  1'b0, is_neg[2],  1'b0, is_neg[1],  1'b0, is_neg[0]
    };

    wire [63:0] s1_s [0:4];
    wire [63:0] s1_c [0:4];
    csa_64bit st1_0(.in1(pp_aligned[0]),  .in2(pp_aligned[1]),  .in3(pp_aligned[2]),  .sum(s1_s[0]), .carry(s1_c[0]));
    csa_64bit st1_1(.in1(pp_aligned[3]),  .in2(pp_aligned[4]),  .in3(pp_aligned[5]),  .sum(s1_s[1]), .carry(s1_c[1]));
    csa_64bit st1_2(.in1(pp_aligned[6]),  .in2(pp_aligned[7]),  .in3(pp_aligned[8]),  .sum(s1_s[2]), .carry(s1_c[2]));
    csa_64bit st1_3(.in1(pp_aligned[9]),  .in2(pp_aligned[10]), .in3(pp_aligned[11]), .sum(s1_s[3]), .carry(s1_c[3]));
    csa_64bit st1_4(.in1(pp_aligned[12]), .in2(pp_aligned[13]), .in3(pp_aligned[14]), .sum(s1_s[4]), .carry(s1_c[4]));

    wire [63:0] s2_s [0:3];
    wire [63:0] s2_c [0:3];
    csa_64bit st2_0(.in1(s1_s[0]), .in2(s1_c[0]),     .in3(s1_s[1]),      .sum(s2_s[0]), .carry(s2_c[0]));
    csa_64bit st2_1(.in1(s1_c[1]), .in2(s1_s[2]),     .in3(s1_c[2]),      .sum(s2_s[1]), .carry(s2_c[1]));
    csa_64bit st2_2(.in1(s1_s[3]), .in2(s1_c[3]),     .in3(s1_s[4]),      .sum(s2_s[2]), .carry(s2_c[2]));
    csa_64bit st2_3(.in1(s1_c[4]), .in2(pp_aligned[15]), .in3(comp_row),  .sum(s2_s[3]), .carry(s2_c[3]));

    reg [63:0] s2_s_r [0:3];
    reg [63:0] s2_c_r [0:3];
    reg [63:0] s5_s_r;
    reg [63:0] s5_c_r;
    reg [63:0] s4_c1_r;
    reg        valid_in_r;
    reg        valid_s1_r;
    reg        valid_s2_r;
    reg        ready_r;

    // Stage 2: three CSA levels over the registered partial sums.
    wire [63:0] s3_s [0:1];
    wire [63:0] s3_c [0:1];
    csa_64bit st3_0(.in1(s2_s_r[0]), .in2(s2_c_r[0]), .in3(s2_s_r[1]), .sum(s3_s[0]), .carry(s3_c[0]));
    csa_64bit st3_1(.in1(s2_c_r[1]), .in2(s2_s_r[2]), .in3(s2_c_r[2]), .sum(s3_s[1]), .carry(s3_c[1]));

    wire [63:0] s4_s [0:1];
    wire [63:0] s4_c [0:1];
    csa_64bit st4_0(.in1(s3_s[0]),   .in2(s3_c[0]),   .in3(s3_s[1]),   .sum(s4_s[0]), .carry(s4_c[0]));
    csa_64bit st4_1(.in1(s3_c[1]),   .in2(s2_s_r[3]), .in3(s2_c_r[3]), .sum(s4_s[1]), .carry(s4_c[1]));

    wire [63:0] s5_s;
    wire [63:0] s5_c;
    csa_64bit st5_0(.in1(s4_s[0]), .in2(s4_c[0]), .in3(s4_s[1]), .sum(s5_s), .carry(s5_c));

    wire [63:0] final_sum;
    wire [63:0] final_carry;
    // Stage 3: final CSA plus the carry-propagate adder.
    csa_64bit st6_0(.in1(s5_s_r), .in2(s5_c_r), .in3(s4_c1_r), .sum(final_sum), .carry(final_carry));

    wire [31:0] adder_low_out;
    wire [31:0] adder_high_out;
    wire        carry_to_high;

    adder u_adder_low (
        .A    (final_sum[31:0]),
        .B    (final_carry[31:0]),
        .cin  (1'b0),
        .Sum  (adder_low_out),
        .cout (carry_to_high)
    );

    adder u_adder_high (
        .A    (final_sum[63:32]),
        .B    (final_carry[63:32]),
        .cin  (carry_to_high),
        .Sum  (adder_high_out),
        .cout ()
    );

    wire [63:0] product_next = {adder_high_out, adder_low_out};

    assign busy  = valid_in_r || valid_s1_r || valid_s2_r;
    assign ready = ready_r;

    integer j;
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            Product    <= 64'b0;
            a_r        <= 32'b0;
            b_r        <= 32'b0;
            s5_s_r     <= 64'b0;
            s5_c_r     <= 64'b0;
            s4_c1_r    <= 64'b0;
            valid_in_r <= 1'b0;
            valid_s1_r <= 1'b0;
            valid_s2_r <= 1'b0;
            ready_r    <= 1'b0;

            for (j = 0; j < 4; j = j + 1) begin
                s2_s_r[j] <= 64'b0;
                s2_c_r[j] <= 64'b0;
            end
        end
        else begin
            ready_r <= 1'b0;
            valid_in_r <= start;
            valid_s1_r <= valid_in_r;
            valid_s2_r <= valid_s1_r;

            if (start) begin
                a_r <= A;
                b_r <= B;
            end

            if (valid_in_r) begin
                for (j = 0; j < 4; j = j + 1) begin
                    s2_s_r[j] <= s2_s[j];
                    s2_c_r[j] <= s2_c[j];
                end
            end

            if (valid_s1_r) begin
                s5_s_r  <= s5_s;
                s5_c_r  <= s5_c;
                s4_c1_r <= s4_c[1];
            end

            if (valid_s2_r) begin
                Product <= product_next;
                ready_r <= 1'b1;
            end
        end
    end

endmodule
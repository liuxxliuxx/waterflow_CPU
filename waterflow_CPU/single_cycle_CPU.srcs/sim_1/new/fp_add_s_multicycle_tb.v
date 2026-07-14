`timescale 1ns / 1ps

module fp_add_s_multicycle_tb;

    reg         clk;
    reg         rst;
    reg         start;
    reg         sub;
    reg  [31:0] A;
    reg  [31:0] B;
    wire        busy;
    wire        ready;
    wire [31:0] R;
    wire        exc_of;
    wire        exc_uf;
    wire [1:0]  exc_code;
    wire        fpu_exception;
    wire [3:0]  fpu_op = sub ? 4'd2 : 4'd1;

    integer errors;
    integer cycles;

    FPU dut(
        .clk           (clk),
        .rst           (rst),
        .en            (start),
        .A             (A),
        .B             (B),
        .fpu_op        (fpu_op),
        .busy          (busy),
        .ready         (ready),
        .fpu_res       (R),
        .fpu_exception (fpu_exception),
        .exc_code      (exc_code)
    );

    assign exc_of = (exc_code == 2'b10);
    assign exc_uf = (exc_code == 2'b11);

    initial clk = 1'b0;
    always #20 clk = ~clk;

    task run_case;
        input [255:0] name;
        input         case_sub;
        input [31:0]  case_a;
        input [31:0]  case_b;
        input [31:0]  expected_r;
        input         expected_of;
        input         expected_uf;
        begin
            @(negedge clk);
            sub   = case_sub;
            A     = case_a;
            B     = case_b;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            cycles = 0;
            while (!ready && cycles < 40) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (!ready) begin
                $display("FAIL %-24s timeout", name);
                errors = errors + 1;
            end
            else begin
                if ((R !== expected_r) ||
                    (exc_of !== expected_of) ||
                    (exc_uf !== expected_uf)) begin
                    $display(
                        "FAIL %-24s R=%08x expected=%08x of=%b/%b uf=%b/%b cycles=%0d",
                        name, R, expected_r,
                        exc_of, expected_of,
                        exc_uf, expected_uf, cycles
                    );
                    errors = errors + 1;
                end
                else begin
                    $display("PASS %-24s R=%08x cycles=%0d", name, R, cycles);
                end

                @(negedge clk);
                if (ready) begin
                    $display("FAIL %-24s ready wider than one cycle", name);
                    errors = errors + 1;
                end
            end
        end
    endtask

    task run_restart_case;
        begin
            @(negedge clk);
            sub   = 1'b0;
            A     = 32'h3f80_0001;
            B     = 32'hbf80_0000;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            repeat (2) @(negedge clk);
            if (!busy) begin
                $display("FAIL restart case first operation was not busy");
                errors = errors + 1;
            end

            sub   = 1'b0;
            A     = 32'h4000_0000;
            B     = 32'h4040_0000;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            cycles = 0;
            while (!ready && cycles < 40) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (!ready || R !== 32'h40a0_0000) begin
                $display("FAIL restart case R=%08x ready=%b", R, ready);
                errors = errors + 1;
            end
            else begin
                $display("PASS restart while busy       R=%08x cycles=%0d", R, cycles);
            end
            @(negedge clk);
        end
    endtask

    initial begin
        rst    = 1'b0;
        start  = 1'b0;
        sub    = 1'b0;
        A      = 32'b0;
        B      = 32'b0;
        errors = 0;

        repeat (3) @(negedge clk);
        rst = 1'b1;

        run_case("1.0 + 2.0",          1'b0, 32'h3f80_0000, 32'h4000_0000, 32'h4040_0000, 1'b0, 1'b0);
        run_case("1.5 + 2.25",         1'b0, 32'h3fc0_0000, 32'h4010_0000, 32'h4070_0000, 1'b0, 1'b0);
        run_case("1.0 - 0.5",          1'b1, 32'h3f80_0000, 32'h3f00_0000, 32'h3f00_0000, 1'b0, 1'b0);
        run_case("complete cancel",    1'b0, 32'h3f80_0000, 32'hbf80_0000, 32'h0000_0000, 1'b0, 1'b0);
        run_case("near cancel",        1'b0, 32'h3f80_0001, 32'hbf80_0000, 32'h3400_0000, 1'b0, 1'b0);
        run_case("large exponent gap", 1'b0, 32'h3f80_0000, 32'h3080_0000, 32'h3f80_0000, 1'b0, 1'b0);
        run_case("positive zeros",     1'b0, 32'h0000_0000, 32'h8000_0000, 32'h0000_0000, 1'b0, 1'b0);
        run_case("negative zeros",     1'b0, 32'h8000_0000, 32'h8000_0000, 32'h8000_0000, 1'b0, 1'b0);
        run_case("infinity",           1'b0, 32'h7f80_0000, 32'h3f80_0000, 32'h7f80_0000, 1'b0, 1'b0);
        run_case("inf plus neg inf",   1'b0, 32'h7f80_0000, 32'hff80_0000, 32'h7fc0_0000, 1'b0, 1'b0);
        run_case("nan canonical",      1'b0, 32'h7fc1_2345, 32'h3f80_0000, 32'h7fc0_0000, 1'b0, 1'b0);
        run_case("overflow",           1'b0, 32'h7f7f_ffff, 32'h7f7f_ffff, 32'h7f80_0000, 1'b1, 1'b0);
        run_case("smallest subnormal", 1'b1, 32'h0080_0000, 32'h007f_ffff, 32'h0000_0001, 1'b0, 1'b1);
        run_restart_case();

        if (errors == 0)
            $display("FP_ADD_MULTICYCLE_TB_PASS");
        else
            $display("FP_ADD_MULTICYCLE_TB_FAIL errors=%0d", errors);

        $finish;
    end

endmodule

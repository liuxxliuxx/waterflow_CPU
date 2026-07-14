`timescale 1ns / 1ps

module sevenseg_scan_tb;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg [31:0] pattern_lo = 32'h4433_2211;
    reg [31:0] pattern_hi = 32'h8877_6655;
    reg [7:0] enable = 8'h05;
    wire [7:0] seg_csn;
    wire [7:0] seg;
    integer errors = 0;
    integer cycles;
    reg seen_digit0 = 1'b0;
    reg seen_digit2 = 1'b0;
    reg seen_blank = 1'b0;

    always #20 clk = ~clk;

    sevenseg_scan #(.SCAN_DIV(3)) u_dut(
        .clk(clk),
        .rst(rst),
        .pattern_lo(pattern_lo),
        .pattern_hi(pattern_hi),
        .enable(enable),
        .seg_csn(seg_csn),
        .seg(seg)
    );

    initial begin
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        for (cycles = 0; cycles < 80; cycles = cycles + 1) begin
            @(posedge clk);
            #1;
            case (seg_csn)
                8'hfe: begin
                    seen_digit0 = 1'b1;
                    if (seg !== 8'h11) errors = errors + 1;
                end
                8'hfb: begin
                    seen_digit2 = 1'b1;
                    if (seg !== 8'h33) errors = errors + 1;
                end
                8'hff: begin
                    seen_blank = 1'b1;
                    if (seg !== 8'h00) errors = errors + 1;
                end
                default: begin
                    $display("Unexpected or multiple digit selects: %02x", seg_csn);
                    errors = errors + 1;
                end
            endcase
        end

        if (!seen_digit0 || !seen_digit2 || !seen_blank) begin
            $display("Scanner did not visit both enabled digits and blanking state");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: sevenseg_scan_tb");
        else
            $display("FAIL: sevenseg_scan_tb errors=%0d", errors);
        $finish;
    end
endmodule

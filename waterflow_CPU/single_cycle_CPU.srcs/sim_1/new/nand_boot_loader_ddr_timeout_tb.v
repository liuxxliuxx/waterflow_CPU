`timescale 1ns / 1ps

module nand_boot_loader_ddr_timeout_tb;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    wire boot_done;
    wire boot_error;
    wire nand_ce_n, nand_re_n, nand_we_n;

    always #5 clk = ~clk;

    nand_boot_loader #(
        .BOOT_WORDS(32'd1),
        .DDR_TIMEOUT_CYCLES(32'd4)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .ddr_ready(1'b0),
        .ddr_req_valid(),
        .ddr_req_ready(1'b0),
        .ddr_req_addr(),
        .ddr_req_wdata(),
        .ddr_resp_valid(1'b0),
        .nand_d_i(8'hff),
        .nand_d_o(),
        .nand_d_oe(),
        .nand_cle(),
        .nand_ale(),
        .nand_ce_n(nand_ce_n),
        .nand_re_n(nand_re_n),
        .nand_we_n(nand_we_n),
        .nand_wp_n(),
        .nand_rdy(1'b1),
        .boot_done(boot_done),
        .boot_error(boot_error)
    );

    initial begin
        #25 rst_n = 1'b1;
        wait (boot_error);
        #10;
        if (boot_done) $fatal(1, "DDR timeout must not complete boot");
        if ({nand_ce_n, nand_re_n, nand_we_n} !== 3'b111) begin
            $fatal(1, "NAND must be returned to its safe idle state");
        end
        $display("PASS: DDR calibration timeout holds the loader in error");
        $finish;
    end
endmodule

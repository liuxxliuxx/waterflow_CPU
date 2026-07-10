`timescale 1ns / 1ps

module nand_boot_loader_timeout_tb;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg ddr_ready = 1'b0;
    tri [7:0] nand_d;
    wire [7:0] nand_d_o;
    wire nand_d_oe;
    wire nand_cle, nand_ale, nand_ce_n, nand_re_n, nand_we_n, nand_wp_n;
    wire boot_done, boot_error;

    always #5 clk = ~clk;
    assign nand_d = nand_d_oe ? nand_d_o : 8'hzz;

    nand_boot_loader #(
        .BOOT_WORDS(32'd1),
        .RESET_TIMEOUT_CYCLES(32'd4),
        .READ_TIMEOUT_CYCLES(32'd4),
        .MIN_READY_WAIT_CYCLES(32'd1)
    ) dut (
        .clk(clk), .rst_n(rst_n), .ddr_ready(ddr_ready),
        .ddr_req_valid(), .ddr_req_ready(1'b0), .ddr_req_addr(), .ddr_req_wdata(),
        .ddr_resp_valid(1'b0),
        .nand_d_i(nand_d), .nand_d_o(nand_d_o), .nand_d_oe(nand_d_oe),
        .nand_cle(nand_cle), .nand_ale(nand_ale), .nand_ce_n(nand_ce_n),
        .nand_re_n(nand_re_n), .nand_we_n(nand_we_n), .nand_wp_n(nand_wp_n),
        .nand_rdy(1'b0), .boot_done(boot_done), .boot_error(boot_error)
    );

    initial begin
        #25 rst_n = 1'b1;
        #15 ddr_ready = 1'b1;
        wait (boot_error);
        if (boot_done) $fatal(1, "CPU boot must not complete after NAND timeout");
        $display("PASS: NAND ready timeout holds the loader in error");
        $finish;
    end
endmodule

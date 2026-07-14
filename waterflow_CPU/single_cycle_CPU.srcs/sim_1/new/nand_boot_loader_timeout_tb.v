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
    wire [31:0] boot_status;

    always #5 clk = ~clk;
    assign nand_d = nand_d_oe ? nand_d_o : 8'hzz;

    nand_boot_loader #(
        .RESET_TIMEOUT_CYCLES(32'd4),
        .READ_TIMEOUT_CYCLES(32'd4),
        .MIN_READY_WAIT_CYCLES(32'd1)
    ) dut (
        .clk(clk), .rst_n(rst_n), .ddr_ready(ddr_ready),
        .ddr_req_valid(), .ddr_req_ready(1'b0), .ddr_req_we(),
        .ddr_req_wstrb(), .ddr_req_addr(), .ddr_req_wdata(),
        .ddr_resp_valid(1'b0), .ddr_resp_rdata(32'h0),
        .nand_d_i(nand_d), .nand_d_o(nand_d_o), .nand_d_oe(nand_d_oe),
        .nand_cle(nand_cle), .nand_ale(nand_ale), .nand_ce_n(nand_ce_n),
        .nand_re_n(nand_re_n), .nand_we_n(nand_we_n), .nand_wp_n(nand_wp_n),
        .nand_rdy(1'b0), .boot_done(boot_done), .boot_error(boot_error),
        .boot_status(boot_status)
    );

    initial begin
        #25 rst_n = 1'b1;
        #15 ddr_ready = 1'b1;
        wait (boot_error);
        if (boot_done) $fatal(1, "CPU boot must not complete after NAND timeout");
        if (boot_status !== 32'hbad0_0002)
            $fatal(1, "wrong NAND timeout status: %h", boot_status);
        $display("PASS: NAND ready timeout holds the loader in error");
        $finish;
    end
endmodule

module nand_boot_loader_page_timeout_tb;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    tri [7:0] nand_d;
    wire [7:0] nand_d_o;
    wire nand_d_oe;
    wire nand_cle, nand_ale, nand_ce_n, nand_re_n, nand_we_n;
    wire nand_rdy;
    wire boot_done, boot_error;
    wire [31:0] boot_status;

    always #5 clk = ~clk;
    assign nand_d = nand_d_oe ? nand_d_o : 8'hzz;

    nand_boot_flash_model #(
        .MEM_BYTES(4096),
        .STALL_PAGE_READY(1)
    ) nand_model (
        .nand_d(nand_d), .nand_cle(nand_cle), .nand_ale(nand_ale),
        .nand_ce_n(nand_ce_n), .nand_re_n(nand_re_n),
        .nand_we_n(nand_we_n), .nand_rdy(nand_rdy)
    );

    nand_boot_loader #(
        .RESET_TIMEOUT_CYCLES(32'd64),
        .READ_TIMEOUT_CYCLES(32'd4),
        .MIN_READY_WAIT_CYCLES(32'd1)
    ) dut (
        .clk(clk), .rst_n(rst_n), .ddr_ready(1'b1),
        .ddr_req_valid(), .ddr_req_ready(1'b0), .ddr_req_we(),
        .ddr_req_wstrb(), .ddr_req_addr(), .ddr_req_wdata(),
        .ddr_resp_valid(1'b0), .ddr_resp_rdata(32'h0),
        .nand_d_i(nand_d), .nand_d_o(nand_d_o), .nand_d_oe(nand_d_oe),
        .nand_cle(nand_cle), .nand_ale(nand_ale), .nand_ce_n(nand_ce_n),
        .nand_re_n(nand_re_n), .nand_we_n(nand_we_n), .nand_wp_n(),
        .nand_rdy(nand_rdy), .boot_done(boot_done),
        .boot_error(boot_error), .boot_status(boot_status)
    );

    initial begin
        nand_model.fill_ff();
        #25 rst_n = 1'b1;
        wait (boot_error);
        #20;
        if (boot_done)
            $fatal(1, "NAND page timeout released the CPU");
        if (boot_status !== 32'hbad0_0002)
            $fatal(1, "wrong NAND page timeout status: %h", boot_status);
        if (nand_model.byte_index != 0)
            $fatal(1, "NAND data was sampled before page-ready");
        $display("PASS: NAND page-ready timeout reported BAD00002");
        $finish;
    end

    initial begin
        #500_000;
        $fatal(1, "NAND page-ready timeout simulation stalled");
    end
endmodule

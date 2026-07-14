`timescale 1ns / 1ps

module nand_boot_loader_ddr_timeout_tb;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    wire boot_done;
    wire boot_error;
    wire [31:0] boot_status;
    wire nand_ce_n, nand_re_n, nand_we_n;

    always #5 clk = ~clk;

    nand_boot_loader #(
        .DDR_TIMEOUT_CYCLES(32'd4)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .ddr_ready(1'b0),
        .ddr_req_valid(),
        .ddr_req_ready(1'b0),
        .ddr_req_we(),
        .ddr_req_wstrb(),
        .ddr_req_addr(),
        .ddr_req_wdata(),
        .ddr_resp_valid(1'b0),
        .ddr_resp_rdata(32'h0),
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
        .boot_error(boot_error),
        .boot_status(boot_status)
    );

    initial begin
        #25 rst_n = 1'b1;
        wait (boot_error);
        #10;
        if (boot_done) $fatal(1, "DDR timeout must not complete boot");
        if (boot_status !== 32'hbad0_0001)
            $fatal(1, "wrong DDR-ready timeout status: %h", boot_status);
        if ({nand_ce_n, nand_re_n, nand_we_n} !== 3'b111) begin
            $fatal(1, "NAND must be returned to its safe idle state");
        end
        $display("PASS: DDR calibration timeout holds the loader in error");
        $finish;
    end
endmodule

module nand_boot_loader_ddr_req_timeout_tb;
    boot_ddr_path_timeout_env #(.STALL_REQUEST(1)) env();
endmodule

module nand_boot_loader_ddr_resp_timeout_tb;
    boot_ddr_path_timeout_env #(.STALL_REQUEST(0)) env();
endmodule

module boot_ddr_path_timeout_env #(
    parameter integer STALL_REQUEST = 1
);
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    tri [7:0] nand_d;
    wire [7:0] nand_d_o;
    wire nand_d_oe;
    wire nand_cle, nand_ale, nand_ce_n, nand_re_n, nand_we_n;
    wire nand_rdy;
    wire ddr_req_valid;
    wire ddr_req_ready = STALL_REQUEST ? 1'b0 : 1'b1;
    wire boot_done, boot_error;
    wire [31:0] boot_status;
    reg request_seen = 1'b0;
    reg request_accepted = 1'b0;

    always #5 clk = ~clk;
    assign nand_d = nand_d_oe ? nand_d_o : 8'hzz;

    nand_boot_flash_model #(.MEM_BYTES(4096)) nand_model (
        .nand_d(nand_d), .nand_cle(nand_cle), .nand_ale(nand_ale),
        .nand_ce_n(nand_ce_n), .nand_re_n(nand_re_n),
        .nand_we_n(nand_we_n), .nand_rdy(nand_rdy)
    );

    nand_boot_loader #(
        .DDR_TIMEOUT_CYCLES(32'd4),
        .RESET_TIMEOUT_CYCLES(32'd64),
        .READ_TIMEOUT_CYCLES(32'd64),
        .MIN_READY_WAIT_CYCLES(32'd1)
    ) dut (
        .clk(clk), .rst_n(rst_n), .ddr_ready(1'b1),
        .ddr_req_valid(ddr_req_valid), .ddr_req_ready(ddr_req_ready),
        .ddr_req_we(), .ddr_req_wstrb(), .ddr_req_addr(),
        .ddr_req_wdata(), .ddr_resp_valid(1'b0),
        .ddr_resp_rdata(32'h0), .nand_d_i(nand_d),
        .nand_d_o(nand_d_o), .nand_d_oe(nand_d_oe),
        .nand_cle(nand_cle), .nand_ale(nand_ale),
        .nand_ce_n(nand_ce_n), .nand_re_n(nand_re_n),
        .nand_we_n(nand_we_n), .nand_wp_n(), .nand_rdy(nand_rdy),
        .boot_done(boot_done), .boot_error(boot_error),
        .boot_status(boot_status)
    );

    always @(posedge clk) begin
        if (ddr_req_valid)
            request_seen <= 1'b1;
        if (ddr_req_valid && ddr_req_ready)
            request_accepted <= 1'b1;
    end

    initial begin
        nand_model.fill_ff();
        nand_model.put_word(0, 32'h4e42_4f54);
        nand_model.put_word(4, 32'd1);
        nand_model.put_word(8, 32'd5);
        nand_model.put_word(12, 32'h1c00_0000);
        nand_model.put_word(16, 32'h1c00_0000);
        nand_model.put_word(20, 32'hcbf5_3a1c);
        nand_model.put_word(24, 32'd0);
        nand_model.put_word(28, 32'd0);
        nand_model.put_byte(2048, "1");
        nand_model.put_byte(2049, "2");
        nand_model.put_byte(2050, "3");
        nand_model.put_byte(2051, "4");
        nand_model.put_byte(2052, "5");

        #25 rst_n = 1'b1;
        wait (boot_error);
        #20;
        if (boot_done)
            $fatal(1, "DDR timeout released the CPU");
        if (boot_status !== 32'hbad0_0004)
            $fatal(1, "wrong DDR path timeout status: %h", boot_status);
        if (!request_seen)
            $fatal(1, "DDR timeout occurred before a write request");
        if (STALL_REQUEST && request_accepted)
            $fatal(1, "request-ready timeout unexpectedly accepted a write");
        if (!STALL_REQUEST && !request_accepted)
            $fatal(1, "response timeout never accepted its write request");
        $display("PASS: DDR %s timeout reported BAD00004",
                 STALL_REQUEST ? "request-ready" : "response");
        $finish;
    end

    initial begin
        #500_000;
        $fatal(1, "DDR path timeout simulation stalled");
    end
endmodule

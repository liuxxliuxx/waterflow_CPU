`timescale 1ns / 1ps

module nand_header_error_tb;
    boot_image_error_env #(.ERROR_CASE(1)) env();
endmodule

module nand_header_version_error_tb;
    boot_image_error_env #(.ERROR_CASE(2)) env();
endmodule

module nand_header_zero_length_error_tb;
    boot_image_error_env #(.ERROR_CASE(3)) env();
endmodule

module nand_header_oversize_error_tb;
    boot_image_error_env #(.ERROR_CASE(4)) env();
endmodule

module nand_header_load_error_tb;
    boot_image_error_env #(.ERROR_CASE(5)) env();
endmodule

module nand_header_entry_error_tb;
    boot_image_error_env #(.ERROR_CASE(6)) env();
endmodule

module nand_header_flags_error_tb;
    boot_image_error_env #(.ERROR_CASE(7)) env();
endmodule

module nand_header_reserved_error_tb;
    boot_image_error_env #(.ERROR_CASE(8)) env();
endmodule

module nand_crc_error_tb;
    boot_image_error_env #(.ERROR_CASE(9)) env();
endmodule

module boot_image_error_env #(
    parameter integer ERROR_CASE = 1
);
    localparam [31:0] HEADER_MAGIC =
        (ERROR_CASE == 1) ? 32'h0000_0000 : 32'h4e42_4f54;
    localparam [31:0] HEADER_VERSION =
        (ERROR_CASE == 2) ? 32'd2 : 32'd1;
    localparam [31:0] HEADER_LENGTH =
        (ERROR_CASE == 3) ? 32'd0 :
        (ERROR_CASE == 4) ? 32'd129025 : 32'd5;
    localparam [31:0] HEADER_LOAD =
        (ERROR_CASE == 5) ? 32'h1c00_0004 : 32'h1c00_0000;
    localparam [31:0] HEADER_ENTRY =
        (ERROR_CASE == 6) ? 32'h1c00_0004 : 32'h1c00_0000;
    localparam [31:0] HEADER_FLAGS =
        (ERROR_CASE == 7) ? 32'd1 : 32'd0;
    localparam [31:0] HEADER_RESERVED =
        (ERROR_CASE == 8) ? 32'd1 : 32'd0;
    localparam [31:0] HEADER_CRC =
        (ERROR_CASE == 9) ? 32'hcbf5_3a1d : 32'hcbf5_3a1c;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    tri [7:0] nand_d;
    wire [7:0] nand_d_o;
    wire nand_d_oe;
    wire nand_cle, nand_ale, nand_ce_n, nand_re_n, nand_we_n;
    wire nand_rdy;
    wire ddr_req_valid;
    wire ddr_req_ready;
    reg ddr_resp_valid = 1'b0;
    wire boot_done, boot_error;
    wire [31:0] boot_status;
    reg ddr_pending = 1'b0;
    integer write_count = 0;

    always #5 clk = ~clk;
    assign nand_d = nand_d_oe ? nand_d_o : 8'hzz;
    assign ddr_req_ready = !ddr_pending;

    nand_boot_flash_model #(.MEM_BYTES(4096)) nand_model (
        .nand_d(nand_d), .nand_cle(nand_cle), .nand_ale(nand_ale),
        .nand_ce_n(nand_ce_n), .nand_re_n(nand_re_n),
        .nand_we_n(nand_we_n), .nand_rdy(nand_rdy)
    );

    nand_boot_loader #(
        .DDR_TIMEOUT_CYCLES(32'd64),
        .RESET_TIMEOUT_CYCLES(32'd64),
        .READ_TIMEOUT_CYCLES(32'd64),
        .MIN_READY_WAIT_CYCLES(32'd1)
    ) dut (
        .clk(clk), .rst_n(rst_n), .ddr_ready(1'b1),
        .ddr_req_valid(ddr_req_valid), .ddr_req_ready(ddr_req_ready),
        .ddr_req_we(), .ddr_req_wstrb(), .ddr_req_addr(),
        .ddr_req_wdata(), .ddr_resp_valid(ddr_resp_valid),
        .ddr_resp_rdata(32'd0), .nand_d_i(nand_d),
        .nand_d_o(nand_d_o), .nand_d_oe(nand_d_oe),
        .nand_cle(nand_cle), .nand_ale(nand_ale),
        .nand_ce_n(nand_ce_n), .nand_re_n(nand_re_n),
        .nand_we_n(nand_we_n), .nand_wp_n(), .nand_rdy(nand_rdy),
        .boot_done(boot_done), .boot_error(boot_error),
        .boot_status(boot_status)
    );

    always @(posedge clk) begin
        ddr_resp_valid <= 1'b0;
        if (ddr_req_valid && ddr_req_ready) begin
            write_count <= write_count + 1;
            ddr_pending <= 1'b1;
        end else if (ddr_pending) begin
            ddr_pending <= 1'b0;
            ddr_resp_valid <= 1'b1;
        end
    end

    initial begin
        nand_model.fill_ff();
        nand_model.put_word(0, HEADER_MAGIC);
        nand_model.put_word(4, HEADER_VERSION);
        nand_model.put_word(8, HEADER_LENGTH);
        nand_model.put_word(12, HEADER_LOAD);
        nand_model.put_word(16, HEADER_ENTRY);
        nand_model.put_word(20, HEADER_CRC);
        nand_model.put_word(24, HEADER_FLAGS);
        nand_model.put_word(28, HEADER_RESERVED);
        nand_model.put_byte(2048, "1");
        nand_model.put_byte(2049, "2");
        nand_model.put_byte(2050, "3");
        nand_model.put_byte(2051, "4");
        nand_model.put_byte(2052, "5");

        #25 rst_n = 1'b1;
        wait (boot_error);
        #20;
        if (boot_done)
            $fatal(1, "invalid image released the CPU");
        if (ERROR_CASE == 9) begin
            if (boot_status !== 32'hbad0_0005)
                $fatal(1, "wrong CRC error status: %h", boot_status);
            if (write_count != 2)
                $fatal(1, "CRC case expected two writes, got %0d", write_count);
        end else begin
            if (boot_status !== 32'hbad0_0003)
                $fatal(1, "wrong header error status: %h", boot_status);
            if (write_count != 0)
                $fatal(1, "bad header caused DDR writes");
        end
        $display("PASS: Boot rejected error case %0d", ERROR_CASE);
        $finish;
    end

    initial begin
        #500_000;
        $fatal(1, "error case %0d simulation timeout", ERROR_CASE);
    end
endmodule

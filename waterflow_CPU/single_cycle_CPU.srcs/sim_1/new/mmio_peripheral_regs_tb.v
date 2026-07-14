`timescale 1ns / 1ps

module mmio_peripheral_regs_tb;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg req_valid = 1'b0;
    wire req_ready;
    reg req_we = 1'b0;
    reg [3:0] req_wstrb = 4'h0;
    reg [31:0] req_addr = 32'h0;
    reg [31:0] req_wdata = 32'h0;
    wire resp_valid;
    reg resp_ready = 1'b1;
    wire [31:0] resp_rdata;
    wire resp_err;
    reg ps2_clk = 1'b1;
    reg ps2_dat = 1'b1;
    wire [3:0] vga_r;
    wire [3:0] vga_g;
    wire [3:0] vga_b;
    wire vga_hsync;
    wire vga_vsync;
    wire uart_tx;
    wire [7:0] irq;
    tri [7:0] nand_d;
    wire nand_cle;
    wire nand_ale;
    wire nand_ce_n;
    wire nand_re_n;
    wire nand_we_n;
    wire nand_wp_n;
    wire [15:0] led_value;
    wire [31:0] seg_pattern_lo;
    wire [31:0] seg_pattern_hi;
    wire [7:0] seg_enable;
    integer errors = 0;
    reg [31:0] read_result;

    always #20 clk = ~clk;

    mmio_tdm_bus u_dut(
        .clk(clk),
        .rst(rst),
        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_we(req_we),
        .req_wstrb(req_wstrb),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .resp_valid(resp_valid),
        .resp_ready(resp_ready),
        .resp_rdata(resp_rdata),
        .resp_err(resp_err),
        .ps2_clk(ps2_clk),
        .ps2_dat(ps2_dat),
        .vga_clk(clk),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .uart_tx(uart_tx),
        .uart_rx(1'b1),
        .irq(irq),
        .timer_value(32'h1234_5678),
        .nand_d(nand_d),
        .nand_cle(nand_cle),
        .nand_ale(nand_ale),
        .nand_ce_n(nand_ce_n),
        .nand_re_n(nand_re_n),
        .nand_we_n(nand_we_n),
        .nand_wp_n(nand_wp_n),
        .nand_rdy(1'b1),
        .boot_status(32'hb003_0042),
        .led_value(led_value),
        .seg_pattern_lo(seg_pattern_lo),
        .seg_pattern_hi(seg_pattern_hi),
        .seg_enable(seg_enable)
    );

    task access;
        input write_enable;
        input [31:0] address;
        input [31:0] write_data;
        input [3:0] write_strobe;
        input expected_error;
        begin
            @(negedge clk);
            req_we = write_enable;
            req_addr = address;
            req_wdata = write_data;
            req_wstrb = write_strobe;
            req_valid = 1'b1;
            while (!req_ready)
                @(negedge clk);
            @(posedge clk);
            #1;
            req_valid = 1'b0;
            while (!resp_valid) begin
                @(posedge clk);
                #1;
            end
            read_result = resp_rdata;
            if (resp_err !== expected_error) begin
                $display("MMIO error mismatch at %08x: got=%b expected=%b", address, resp_err, expected_error);
                errors = errors + 1;
            end
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        repeat (6) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        access(1'b1, 32'h1fe5_0000, 32'hdead_beef, 4'hf, 1'b0);
        access(1'b1, 32'h1fe5_0000, 32'h0000_1234, 4'h3, 1'b0);
        access(1'b0, 32'h1fe5_0000, 32'h0, 4'h0, 1'b0);
        if (read_result !== 32'hdead_1234) errors = errors + 1;

        access(1'b1, 32'h1fe5_0004, 32'h8877_6655, 4'hf, 1'b0);
        access(1'b1, 32'h1fe5_0008, 32'h0000_00a5, 4'h1, 1'b0);
        if ((seg_pattern_hi !== 32'h8877_6655) || (seg_enable !== 8'ha5))
            errors = errors + 1;

        access(1'b0, 32'h1fe5_000c, 32'h0, 4'h0, 1'b0);
        if (read_result !== 32'hb003_0042) errors = errors + 1;
        access(1'b1, 32'h1fe5_000c, 32'h0, 4'hf, 1'b1);

        access(1'b1, 32'h1fe6_0000, 32'h0000_1234, 4'h3, 1'b0);
        access(1'b0, 32'h1fe6_0000, 32'h0, 4'h0, 1'b0);
        if ((read_result !== 32'h0000_1234) || (led_value !== 16'h1234))
            errors = errors + 1;
        access(1'b0, 32'h1fe6_0004, 32'h0, 4'h0, 1'b1);

        if (errors == 0)
            $display("PASS: mmio_peripheral_regs_tb");
        else
            $display("FAIL: mmio_peripheral_regs_tb errors=%0d", errors);
        $finish;
    end
endmodule

// Lightweight integration coverage for the board-facing logic extracted from
// soc_top. This avoids elaborating the MIG while testing the exact module used
// by the production top level.
module soc_boot_board_control_tb;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg ddr_ready_async = 1'b0;
    reg nand_rdy_async = 1'b0;
    reg boot_done = 1'b0;
    reg boot_error = 1'b0;
    reg [31:0] boot_status = 32'hb001_0000;
    reg [15:0] mmio_led_value = 16'h1234;
    reg [31:0] mmio_seg_pattern_lo = 32'h1122_3344;
    reg [31:0] mmio_seg_pattern_hi = 32'h5566_7788;
    reg [7:0] mmio_seg_enable = 8'ha5;
    wire ddr_ready;
    wire nand_rdy;
    wire cpu_rst_n;
    wire nand_boot_owner;
    wire nand_cle, nand_ale, nand_ce_n, nand_re_n, nand_we_n;
    wire [15:0] led;
    wire [1:0] led_dual_r, led_dual_g;
    wire [31:0] active_seg_pattern_lo, active_seg_pattern_hi;
    wire [7:0] active_seg_enable;
    wire boot_display_active;
    integer errors = 0;

    always #5 clk = ~clk;

    soc_boot_board_control #(
        .BOOT_DISPLAY_HOLD_CYCLES(3)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .ddr_ready_async(ddr_ready_async),
        .nand_rdy_async(nand_rdy_async),
        .boot_done(boot_done), .boot_error(boot_error),
        .boot_status(boot_status), .mmio_led_value(mmio_led_value),
        .mmio_seg_pattern_lo(mmio_seg_pattern_lo),
        .mmio_seg_pattern_hi(mmio_seg_pattern_hi),
        .mmio_seg_enable(mmio_seg_enable),
        .nand_boot_cle(1'b1), .nand_boot_ale(1'b0),
        .nand_boot_ce_n(1'b0), .nand_boot_re_n(1'b1),
        .nand_boot_we_n(1'b0),
        .nand_mmio_cle(1'b0), .nand_mmio_ale(1'b1),
        .nand_mmio_ce_n(1'b1), .nand_mmio_re_n(1'b0),
        .nand_mmio_we_n(1'b1),
        .ddr_ready(ddr_ready), .nand_rdy(nand_rdy),
        .cpu_rst_n(cpu_rst_n), .nand_boot_owner(nand_boot_owner),
        .nand_cle(nand_cle), .nand_ale(nand_ale),
        .nand_ce_n(nand_ce_n), .nand_re_n(nand_re_n),
        .nand_we_n(nand_we_n), .led(led),
        .led_dual_r(led_dual_r), .led_dual_g(led_dual_g),
        .active_seg_pattern_lo(active_seg_pattern_lo),
        .active_seg_pattern_hi(active_seg_pattern_hi),
        .active_seg_enable(active_seg_enable),
        .boot_display_active(boot_display_active)
    );

    task check_condition;
        input condition;
        input [255:0] message;
        begin
            if (!condition) begin
                $display("FAIL: %s", message);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        ddr_ready_async = 1'b1;
        nand_rdy_async = 1'b1;

        @(posedge clk); #1;
        check_condition(!ddr_ready && !nand_rdy,
               "synchronizers must not pass an async input in one stage");
        @(posedge clk); #1;
        check_condition(ddr_ready && nand_rdy,
               "DDR ready and NAND ready must pass through two stages");
        check_condition(!cpu_rst_n, "CPU released before Boot completion");
        check_condition(nand_boot_owner &&
               ({nand_cle, nand_ale, nand_ce_n, nand_re_n, nand_we_n} ==
                5'b10010),
               "Boot NAND controls were not selected before boot_done");
        check_condition(led == 16'hedcb, "logical LED value was not inverted at pins");
        check_condition(boot_display_active && active_seg_enable == 8'hff,
               "Boot display was not active before completion");
        check_condition(active_seg_pattern_lo == 32'h063f_3f7c &&
               active_seg_pattern_hi == 32'h3f3f_3f3f,
               "B0010000 segment order or encoding is wrong");

        @(negedge clk);
        boot_status = 32'hb007_0000;
        boot_done = 1'b1;
        @(posedge clk); #1;
        check_condition(cpu_rst_n, "CPU was not released after DDR ready and boot_done");
        check_condition(!nand_boot_owner &&
               ({nand_cle, nand_ale, nand_ce_n, nand_re_n, nand_we_n} ==
                5'b01101),
               "MMIO NAND controls were not selected after boot_done");
        check_condition(led_dual_r == 2'b11 && led_dual_g == 2'b00,
               "production green status LEDs are wrong after Boot");
        check_condition(boot_display_active, "B007 display hold ended too early");
        check_condition(active_seg_pattern_lo == 32'h073f_3f7c &&
               active_seg_pattern_hi == 32'h3f3f_3f3f,
               "B0070000 was not retained during the display hold");
        @(posedge clk); #1;
        check_condition(boot_display_active, "B007 display hold lost a cycle");
        @(posedge clk); #1;
        check_condition(!boot_display_active &&
               active_seg_pattern_lo == mmio_seg_pattern_lo &&
               active_seg_pattern_hi == mmio_seg_pattern_hi &&
               active_seg_enable == mmio_seg_enable,
               "display did not return to software after the hold interval");

        @(negedge clk);
        ddr_ready_async = 1'b0;
        nand_rdy_async = 1'b0;
        @(posedge clk); #1;
        check_condition(ddr_ready && nand_rdy,
               "ready synchronizers changed after only one falling sample");
        @(posedge clk); #1;
        check_condition(!ddr_ready && !nand_rdy && !cpu_rst_n,
               "ready deassertion did not reapply the CPU reset gate");

        @(negedge clk);
        boot_done = 1'b0;
        boot_error = 1'b1;
        boot_status = 32'hbad0_0005;
        ddr_ready_async = 1'b1;
        @(posedge clk); #1;
        check_condition(boot_display_active && nand_boot_owner,
               "Boot error did not retain display/NAND ownership");
        check_condition(led_dual_g == 2'b10,
               "Boot error did not light the second red status LED");

        if (errors == 0)
            $display("PASS: soc_boot_board_control_tb");
        else
            $fatal(1, "soc_boot_board_control_tb errors=%0d", errors);
        $finish;
    end
endmodule

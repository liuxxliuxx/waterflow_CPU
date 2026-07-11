`timescale 1ns / 1ps

// End-to-end regression for the raw NAND image format used by NAND_writer.
// A small functional MIG model replaces the physical DDR3 model so the test
// focuses on the complete boot chain: NAND -> boot loader -> DDR -> CPU -> LED.
module soc_nand_led_demo_tb;
    reg sys_clk_i = 1'b0;
    reg rst_n = 1'b0;
    tri [7:0] nand_d;
    reg [7:0] nand_mem [0:4095];
    reg nand_rdy = 1'b1;
    reg [7:0] nand_addr [0:4];
    reg [2:0] nand_addr_count = 3'd0;
    integer nand_byte_index = 0;
    integer i;

    wire uart_tx;
    wire [7:0] led;
    wire nand_cle, nand_ale, nand_ce_n, nand_re_n, nand_we_n;
    wire [12:0] ddr3_addr;
    wire [2:0] ddr3_ba;
    wire ddr3_cas_n, ddr3_ras_n, ddr3_reset_n, ddr3_we_n;
    wire [0:0] ddr3_ck_n, ddr3_ck_p, ddr3_cke, ddr3_odt;
    tri [15:0] ddr3_dq;
    tri [1:0] ddr3_dqs_n, ddr3_dqs_p;
    wire [1:0] ddr3_dm;

    always #5 sys_clk_i = ~sys_clk_i;

    soc_top dut (
        .sys_clk_i(sys_clk_i),
        .rst_n(rst_n),
        .uart_tx(uart_tx),
        .uart_rx(1'b1),
        .led(led),
        .nand_d(nand_d),
        .nand_cle(nand_cle),
        .nand_ale(nand_ale),
        .nand_ce_n(nand_ce_n),
        .nand_re_n(nand_re_n),
        .nand_we_n(nand_we_n),
        .nand_rdy(nand_rdy),
        .ddr3_addr(ddr3_addr),
        .ddr3_ba(ddr3_ba),
        .ddr3_cas_n(ddr3_cas_n),
        .ddr3_ck_n(ddr3_ck_n),
        .ddr3_ck_p(ddr3_ck_p),
        .ddr3_cke(ddr3_cke),
        .ddr3_ras_n(ddr3_ras_n),
        .ddr3_reset_n(ddr3_reset_n),
        .ddr3_we_n(ddr3_we_n),
        .ddr3_dq(ddr3_dq),
        .ddr3_dqs_n(ddr3_dqs_n),
        .ddr3_dqs_p(ddr3_dqs_p),
        .ddr3_dm(ddr3_dm),
        .ddr3_odt(ddr3_odt)
    );

    // K9F1G08U0C main-area read model. The boot loader reads raw page data,
    // without OOB bytes between its 2 KiB pages.
    assign nand_d = (!nand_ce_n && !nand_re_n) ? nand_mem[nand_byte_index] : 8'hzz;

    always @(posedge nand_we_n) begin
        if (!nand_ce_n) begin
            if (nand_cle) begin
                if (nand_d == 8'hff) begin
                    nand_rdy <= 1'b0;
                    nand_addr_count <= 3'd0;
                    #200 nand_rdy <= 1'b1;
                end else if (nand_d == 8'h00) begin
                    nand_addr_count <= 3'd0;
                end else if (nand_d == 8'h30) begin
                    nand_byte_index <= {nand_addr[3], nand_addr[2],
                                        nand_addr[1][2:0], nand_addr[0][7:2],
                                        2'b00};
                    nand_rdy <= 1'b0;
                    #200 nand_rdy <= 1'b1;
                end
            end else if (nand_ale) begin
                nand_addr[nand_addr_count] <= nand_d;
                nand_addr_count <= nand_addr_count + 3'd1;
            end
        end
    end

    always @(posedge nand_re_n) begin
        if (!nand_ce_n) begin
            nand_byte_index <= nand_byte_index + 1;
        end
    end

    task put_word;
        input integer byte_offset;
        input [31:0] word;
        begin
            nand_mem[byte_offset + 0] = word[7:0];
            nand_mem[byte_offset + 1] = word[15:8];
            nand_mem[byte_offset + 2] = word[23:16];
            nand_mem[byte_offset + 3] = word[31:24];
        end
    endtask

    initial begin
        for (i = 0; i < 4096; i = i + 1) begin
            nand_mem[i] = 8'hff;
        end

        // tools/build/nand_led_vga_demo.bin, copied to NAND page 0 directly.
        put_word(12'h000, 32'h1439_ffe3);
        put_word(12'h004, 32'h1c00_000c);
        put_word(12'h008, 32'h028b_a18c);
        put_word(12'h00c, 32'h1c00_000d);
        put_word(12'h010, 32'h028b_81ad);
        put_word(12'h014, 32'h5800_118d);
        put_word(12'h018, 32'h2980_0180);
        put_word(12'h01c, 32'h0280_118c);
        put_word(12'h020, 32'h53ff_f7ff);
        put_word(12'h024, 32'h5402_9000);
        put_word(12'h028, 32'h5000_0000);

        put_word(12'h298, 32'h143f_cc0c);
        put_word(12'h29c, 32'h2980_0184);
        put_word(12'h2a0, 32'h4c00_0020);

        put_word(12'h2b4, 32'h02bf_c063);
        put_word(12'h2b8, 32'h0283_2804);
        put_word(12'h2bc, 32'h2980_3061);
        put_word(12'h2c0, 32'h57ff_dbff);
        put_word(12'h2c4, 32'h57fd_6bff);
        put_word(12'h2c8, 32'h1c00_0006);
        put_word(12'h2cc, 32'h0280_60c6);
        put_word(12'h2d0, 32'h0015_0005);
        put_word(12'h2d4, 32'h0015_0004);
        put_word(12'h2d8, 32'h57fd_dfff);
        put_word(12'h2dc, 32'h5000_0000);

        #200 rst_n = 1'b1;
        wait (dut.boot_done || dut.boot_error);
        if (dut.boot_error) begin
            $fatal(1, "boot loader reported an error");
        end
        wait (dut.mmio_led_value == 8'hca);
        if (led !== 8'hca) begin
            $fatal(1, "LED output mismatch: expected ca, got %h", led);
        end
        $display("PASS: raw NAND image booted and wrote LED 8'hca");
        $finish;
    end

    initial begin
        #5000000;
        $display("BOOT done=%b error=%b state=%0d words=%0d cpu_rst_n=%b pc=%h led_mmio=%h led=%h",
                 dut.boot_done, dut.boot_error, dut.u_boot_loader.state,
                 dut.u_boot_loader.words_written,
                 dut.cpu_rst_n, dut.u_cpu.u_ifu.out_pc, dut.mmio_led_value, led);
        $fatal(1, "SoC NAND LED regression timed out");
    end
endmodule

// Functional replacement for the MMCM during this logic-level test.
module clk_ref_200_gen(
    input wire clk_in,
    input wire rst,
    output wire clk_out,
    output wire locked
);
    assign clk_out = clk_in;
    assign locked = !rst;
endmodule

// Functional 128-bit MIG application-port model. It preserves the data/mask
// behavior used by ddr3_mig_bridge while avoiding DDR3 PHY simulation time.
module mig_7series_0(
    inout wire [15:0] ddr3_dq,
    inout wire [1:0] ddr3_dqs_n,
    inout wire [1:0] ddr3_dqs_p,
    output wire [12:0] ddr3_addr,
    output wire [2:0] ddr3_ba,
    output wire ddr3_ras_n,
    output wire ddr3_cas_n,
    output wire ddr3_we_n,
    output wire ddr3_reset_n,
    output wire [0:0] ddr3_ck_p,
    output wire [0:0] ddr3_ck_n,
    output wire [0:0] ddr3_cke,
    output wire [1:0] ddr3_dm,
    output wire [0:0] ddr3_odt,
    input wire sys_clk_i,
    input wire clk_ref_i,
    input wire [26:0] app_addr,
    input wire [2:0] app_cmd,
    input wire app_en,
    input wire [127:0] app_wdf_data,
    input wire app_wdf_end,
    input wire [15:0] app_wdf_mask,
    input wire app_wdf_wren,
    output reg [127:0] app_rd_data,
    output wire app_rd_data_end,
    output reg app_rd_data_valid,
    output wire app_rdy,
    output wire app_wdf_rdy,
    input wire app_sr_req,
    input wire app_ref_req,
    input wire app_zq_req,
    output wire app_sr_active,
    output wire app_ref_ack,
    output wire app_zq_ack,
    output wire ui_clk,
    output wire ui_clk_sync_rst,
    output reg init_calib_complete,
    output wire [11:0] device_temp,
    input wire sys_rst
);
    localparam [2:0] CMD_WRITE = 3'b000;
    localparam [2:0] CMD_READ  = 3'b001;

    reg [127:0] memory [0:4095];
    reg [3:0] init_count;
    reg read_pending;
    reg [11:0] read_index;
    integer byte_lane;

    assign ui_clk = sys_clk_i;
    assign ui_clk_sync_rst = sys_rst || !init_calib_complete;
    assign app_rdy = init_calib_complete;
    assign app_wdf_rdy = init_calib_complete;
    assign app_rd_data_end = app_rd_data_valid;
    assign ddr3_addr = 13'h0;
    assign ddr3_ba = 3'h0;
    assign ddr3_ras_n = 1'b1;
    assign ddr3_cas_n = 1'b1;
    assign ddr3_we_n = 1'b1;
    assign ddr3_reset_n = !sys_rst;
    assign ddr3_ck_p = 1'b0;
    assign ddr3_ck_n = 1'b0;
    assign ddr3_cke = 1'b0;
    assign ddr3_dm = 2'b0;
    assign ddr3_odt = 1'b0;
    assign app_sr_active = 1'b0;
    assign app_ref_ack = 1'b0;
    assign app_zq_ack = 1'b0;
    assign device_temp = 12'h000;

    always @(posedge sys_clk_i) begin
        if (sys_rst) begin
            init_count <= 4'd0;
            init_calib_complete <= 1'b0;
            read_pending <= 1'b0;
            app_rd_data_valid <= 1'b0;
            app_rd_data <= 128'h0;
        end else begin
            app_rd_data_valid <= 1'b0;
            if (!init_calib_complete) begin
                init_count <= init_count + 4'd1;
                if (init_count == 4'd8) begin
                    init_calib_complete <= 1'b1;
                end
            end

            if (read_pending) begin
                app_rd_data <= memory[read_index];
                app_rd_data_valid <= 1'b1;
                read_pending <= 1'b0;
            end

            if (app_en && app_rdy && app_cmd == CMD_READ) begin
                read_index <= app_addr[13:2];
                read_pending <= 1'b1;
            end

            if (app_en && app_wdf_wren && app_rdy && app_cmd == CMD_WRITE) begin
                for (byte_lane = 0; byte_lane < 16; byte_lane = byte_lane + 1) begin
                    if (!app_wdf_mask[byte_lane]) begin
                        memory[app_addr[13:2]][byte_lane * 8 +: 8] <=
                            app_wdf_data[byte_lane * 8 +: 8];
                    end
                end
            end
        end
    end
endmodule

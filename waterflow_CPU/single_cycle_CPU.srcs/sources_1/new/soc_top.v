`timescale 1ns / 1ps

module soc_top #(
    parameter [24:0] BOOT_NAND_START_WORD = 25'd0,
    parameter [31:0] BOOT_LOAD_ADDR = 32'h1c00_0000,
    parameter [31:0] BOOT_MAX_PAYLOAD_BYTES = 32'd8386560
) (
    input  wire        sys_clk_i,
    input  wire        rst_n,

    output wire        uart_tx,
    input  wire        uart_rx,
    input  wire        ps2_clk,
    input  wire        ps2_dat,
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire        vga_hsync,
    output wire        vga_vsync,
    output wire [15:0] led,
    output wire [1:0]  led_dual_r,
    output wire [1:0]  led_dual_g,
    output wire [7:0]  seg_csn,
    output wire [7:0]  seg,

    output wire        lcd_rst,
    output wire        lcd_cs,
    output wire        lcd_rs,
    output wire        lcd_wr,
    output wire        lcd_rd,
    inout  wire [15:0] lcd_data_io,
    output wire        lcd_bl_ctr,
    inout  wire        ct_int,
    inout  wire        ct_sda,
    output wire        ct_scl,
    output wire        ct_rstn,

    inout  wire [7:0]  nand_d,
    output wire        nand_cle,
    output wire        nand_ale,
    output wire        nand_ce_n,
    output wire        nand_re_n,
    output wire        nand_we_n,
    input  wire        nand_rdy,

    output wire [12:0] ddr3_addr,
    output wire [2:0]  ddr3_ba,
    output wire        ddr3_cas_n,
    output wire [0:0]  ddr3_ck_n,
    output wire [0:0]  ddr3_ck_p,
    output wire [0:0]  ddr3_cke,
    output wire        ddr3_ras_n,
    output wire        ddr3_reset_n,
    output wire        ddr3_we_n,
    inout  wire [15:0] ddr3_dq,
    inout  wire [1:0]  ddr3_dqs_n,
    inout  wire [1:0]  ddr3_dqs_p,
    output wire [1:0]  ddr3_dm,
    output wire [0:0]  ddr3_odt
);
    wire ddr_ui_clk;
    wire ddr_ui_rst;
    wire ddr_init_calib_complete;
    wire cpu_clk_25;
    wire ddr_clk_100;
    wire vga_clk_25;
    wire clk_wiz_locked;
    wire clock_reset_n;
    wire clk25_reset_n;
    wire ddr_reset_n;
    wire cpu_rst_n;
    wire ddr_ready_25;

    wire inst_req_valid;
    wire inst_req_ready;
    wire [31:0] inst_req_vaddr;
    wire inst_resp_valid;
    wire [31:0] inst_resp_data;
    wire inst_resp_err;

    wire data_req_valid;
    wire data_req_ready;
    wire data_req_we;
    wire [31:0] data_req_vaddr;
    wire [31:0] data_req_wdata;
    wire [3:0] data_req_wstrb;
    wire [1:0] data_req_size;
    wire data_resp_valid;
    wire [31:0] data_resp_rdata;
    wire data_resp_err;

    wire boot_done;
    wire boot_error;
    wire [31:0] boot_status;

    wire [7:0] irq;
    wire nand_rdy_25;
    wire nand_wp_unused;
    wire [4:0]  lcd_test_addr;
    wire [31:0] lcd_test_data;
    wire [31:0] lcd_test_pc_cur;
    wire [31:0] lcd_test_inst;

    // clk_wiz_0 is the sole fabric clock source.  clk_out1 drives the shared
    // CPU/memory-control domain, clk_out2 supplies the 100 MHz MIG system
    // clock, and clk_out3 is reserved for the VGA pixel pipeline.
    clk_wiz_0 u_clk_wiz_0 (
        .clk_out1(cpu_clk_25),
        .clk_out2(ddr_clk_100),
        .clk_out3(vga_clk_25),
        .reset(!rst_n),
        .locked(clk_wiz_locked),
        .clk_in1(sys_clk_i)
    );

    assign clock_reset_n = rst_n && clk_wiz_locked;

    // Assert reset asynchronously and release it only after each clock is
    // running.  This prevents logic from starting while the MMCM is locking.
    soc_reset_sync u_cpu_reset_sync (
        .clk(cpu_clk_25),
        .arst_n(clock_reset_n),
        .rst_n(clk25_reset_n)
    );

    soc_reset_sync u_ddr_reset_sync (
        .clk(ddr_clk_100),
        .arst_n(clock_reset_n),
        .rst_n(ddr_reset_n)
    );

    soc_boot_board_control u_boot_board_control (
        .clk(cpu_clk_25),
        .rst_n(clk25_reset_n),
        .ddr_ready_async(ddr_init_calib_complete && !ddr_ui_rst),
        .nand_rdy_async(nand_rdy),
        .boot_done(boot_done),
        .boot_error(boot_error),
        .ddr_ready(ddr_ready_25),
        .nand_rdy(nand_rdy_25),
        .cpu_rst_n(cpu_rst_n),
        .led_dual_r(led_dual_r),
        .led_dual_g(led_dual_g)
    );

    CPU u_cpu (
        .clk(cpu_clk_25),
        .rst(cpu_rst_n),
        .test_addr(lcd_test_addr),
        .test_data(lcd_test_data),
        .test_pc_cur(lcd_test_pc_cur),
        .test_inst(lcd_test_inst),
        .inst_req_valid(inst_req_valid),
        .inst_req_ready(inst_req_ready),
        .inst_req_vaddr(inst_req_vaddr),
        .inst_resp_valid(inst_resp_valid),
        .inst_resp_data(inst_resp_data),
        .inst_resp_err(inst_resp_err),
        .data_req_valid(data_req_valid),
        .data_req_ready(data_req_ready),
        .data_req_we(data_req_we),
        .data_req_vaddr(data_req_vaddr),
        .data_req_wdata(data_req_wdata),
        .data_req_wstrb(data_req_wstrb),
        .data_req_size(data_req_size),
        .data_resp_valid(data_resp_valid),
        .data_resp_rdata(data_resp_rdata),
        .data_resp_err(data_resp_err),
        .hw_int(irq)
    );

    lcd_cpu_display u_lcd_cpu_display (
        .clk(cpu_clk_25),
        .resetn(clk25_reset_n),
        .lcd_rst(lcd_rst),
        .lcd_cs(lcd_cs),
        .lcd_rs(lcd_rs),
        .lcd_wr(lcd_wr),
        .lcd_rd(lcd_rd),
        .lcd_data_io(lcd_data_io),
        .lcd_bl_ctr(lcd_bl_ctr),
        .ct_int(ct_int),
        .ct_sda(ct_sda),
        .ct_scl(ct_scl),
        .ct_rstn(ct_rstn),
        .test_addr(lcd_test_addr),
        .test_data(lcd_test_data),
        .test_pc_cur(lcd_test_pc_cur),
        .test_inst(lcd_test_inst)
    );

    mem_subsystem #(
        .BOOT_NAND_START_WORD(BOOT_NAND_START_WORD),
        .BOOT_LOAD_ADDR(BOOT_LOAD_ADDR),
        .BOOT_MAX_PAYLOAD_BYTES(BOOT_MAX_PAYLOAD_BYTES)
    ) u_mem_subsystem (
        .clk(cpu_clk_25),
        .rst(clk25_reset_n),
        .i_req_valid(inst_req_valid && cpu_rst_n),
        .i_req_ready(inst_req_ready),
        .i_req_vaddr(inst_req_vaddr),
        .i_resp_valid(inst_resp_valid),
        .i_resp_ready(1'b1),
        .i_resp_inst(inst_resp_data),
        .i_resp_err(inst_resp_err),
        .resp_exc_valid(),
        .d_req_valid(data_req_valid && cpu_rst_n),
        .d_req_ready(data_req_ready),
        .d_req_we(data_req_we),
        .d_req_size(data_req_size),
        .d_req_wstrb(data_req_wstrb),
        .d_req_vaddr(data_req_vaddr),
        .d_req_wdata(data_req_wdata),
        .d_resp_valid(data_resp_valid),
        .d_resp_ready(1'b1),
        .d_resp_rdata(data_resp_rdata),
        .d_resp_err(data_resp_err),
        .boot_done(boot_done),
        .boot_error(boot_error),
        .boot_status(boot_status),
        .boot_ddr_ready(ddr_ready_25),
        .ps2_clk(ps2_clk),
        .ps2_dat(ps2_dat),
        .vga_clk(vga_clk_25),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .irq(irq),
        .led(led),
        .seg_csn(seg_csn),
        .seg(seg),
        .nand_d(nand_d),
        .nand_cle(nand_cle),
        .nand_ale(nand_ale),
        .nand_ce_n(nand_ce_n),
        .nand_re_n(nand_re_n),
        .nand_we_n(nand_we_n),
        .nand_wp_n(nand_wp_unused),
        .nand_rdy(nand_rdy_25),
        .ddr_sys_clk_i(ddr_clk_100),
        .ddr_rst_n(ddr_reset_n),
        .ddr_ui_clk(ddr_ui_clk),
        .ddr_ui_rst(ddr_ui_rst),
        .ddr_init_calib_complete(ddr_init_calib_complete),
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

endmodule

// Reset assertion is immediate.  Release is synchronized locally so every
// clock domain starts only after clk_wiz_0 reports a stable clock.
module soc_reset_sync (
    input  wire clk,
    input  wire arst_n,
    output wire rst_n
);
    (* ASYNC_REG = "TRUE" *) reg [1:0] release_sync;

    always @(posedge clk or negedge arst_n) begin
        if (!arst_n)
            release_sync <= 2'b00;
        else
            release_sync <= {release_sync[0], 1'b1};
    end

    assign rst_n = release_sync[1];
endmodule

module soc_boot_board_control (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ddr_ready_async,
    input  wire        nand_rdy_async,
    input  wire        boot_done,
    input  wire        boot_error,
    output wire        ddr_ready,
    output wire        nand_rdy,
    output wire        cpu_rst_n,
    output wire [1:0]  led_dual_r,
    output wire [1:0]  led_dual_g
);
    (* ASYNC_REG = "TRUE" *) reg [1:0] ddr_ready_sync;
    (* ASYNC_REG = "TRUE" *) reg [1:0] nand_rdy_sync;

    assign ddr_ready = ddr_ready_sync[1];
    assign nand_rdy = nand_rdy_sync[1];
    assign cpu_rst_n = rst_n && ddr_ready && boot_done;
    // Board R/G net names are physically reversed, so *_r lights green.
    assign led_dual_r = {boot_done, ddr_ready};
    assign led_dual_g = {boot_error, 1'b0};

    // Synchronize asynchronous MIG/NAND readiness into the 25 MHz domain.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ddr_ready_sync <= 2'b00;
            nand_rdy_sync <= 2'b00;
        end else begin
            ddr_ready_sync <= {ddr_ready_sync[0], ddr_ready_async};
            nand_rdy_sync <= {nand_rdy_sync[0], nand_rdy_async};
        end
    end
endmodule

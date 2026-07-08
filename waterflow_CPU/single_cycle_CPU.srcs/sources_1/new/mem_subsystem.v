`timescale 1ns / 1ps

module mem_subsystem(
    input wire clk,
    input wire rst,
    input wire i_req_valid,
    output wire i_req_ready,
    input wire [31:0] i_req_vaddr,
    output reg i_resp_valid,
    input wire i_resp_ready,
    output reg [31:0] i_resp_inst,
    output reg i_resp_exc_valid,
    output reg [5:0] i_resp_ecode,
    output reg [31:0] i_resp_badv,
    input wire d_req_valid,
    output wire d_req_ready,
    input wire d_req_we,
    input wire [1:0] d_req_size,
    input wire [3:0] d_req_wstrb,
    input wire [31:0] d_req_vaddr,
    input wire [31:0] d_req_wdata,
    output reg d_resp_valid,
    input wire d_resp_ready,
    output reg [31:0] d_resp_rdata,
    output reg d_resp_exc_valid,
    output reg [5:0] d_resp_ecode,
    output reg [31:0] d_resp_badv,
    input wire ps2_clk,
    input wire ps2_dat,
    input wire vga_clk,
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b,
    output wire vga_hsync,
    output wire vga_vsync,
    output wire uart_tx,
    input wire uart_rx,
    output wire [7:0] irq,
    output wire [7:0] led_value,
    output wire [31:0] diag_value,
    inout wire [7:0] nand_d,
    output wire nand_cle,
    output wire nand_ale,
    output wire nand_ce_n,
    output wire nand_re_n,
    output wire nand_we_n,
    output wire nand_wp_n,
    input wire nand_rdy,
    input wire ddr_sys_clk_i,
    output wire ddr_ui_clk,
    output wire ddr_ui_rst,
    output wire ddr_init_calib_complete,
    output wire [12:0] ddr3_addr,
    output wire [2:0] ddr3_ba,
    output wire ddr3_cas_n,
    output wire [0:0] ddr3_ck_n,
    output wire [0:0] ddr3_ck_p,
    output wire [0:0] ddr3_cke,
    output wire ddr3_ras_n,
    output wire ddr3_reset_n,
    output wire ddr3_we_n,
    inout wire [15:0] ddr3_dq,
    inout wire [1:0] ddr3_dqs_n,
    inout wire [1:0] ddr3_dqs_p,
    output wire [1:0] ddr3_dm,
    output wire [0:0] ddr3_odt
);
    reg [31:0] timer;
    reg ddr_resp_is_d;
    reg [31:0] ddr_resp_badv;

    wire rst_hi = !rst;

    wire d_is_mmio =
        (d_req_vaddr[31:16] == 16'h1fe0) ||
        (d_req_vaddr[31:16] == 16'h1fe1) ||
        (d_req_vaddr[31:16] == 16'h1fe2) ||
        (d_req_vaddr[31:16] == 16'h1fe3) ||
        (d_req_vaddr[31:16] == 16'h1fe6) ||
        (d_req_vaddr[31:16] == 16'h1fd0);

    wire i_resp_room = !i_resp_valid || i_resp_ready;
    wire d_resp_room = !d_resp_valid || d_resp_ready;

    wire d_ddr_sel = d_req_valid && !d_is_mmio && d_resp_room;
    wire i_ddr_sel = i_req_valid && i_resp_room && !d_ddr_sel;
    wire ddr_req_valid = d_ddr_sel || i_ddr_sel;
    wire ddr_req_ready;
    wire ddr_req_fire = ddr_req_valid && ddr_req_ready;
    wire ddr_req_we = d_ddr_sel && d_req_we;
    wire [3:0] ddr_req_wstrb = d_ddr_sel ? d_req_wstrb : 4'b0000;
    wire [31:0] ddr_req_addr = d_ddr_sel ? d_req_vaddr : i_req_vaddr;
    wire [31:0] ddr_req_wdata = d_req_wdata;
    wire ddr_resp_valid;
    wire ddr_resp_ready = ddr_resp_is_d ? d_resp_room : i_resp_room;
    wire [31:0] ddr_resp_rdata;

    wire [7:0] ps2_rdata;
    wire ps2_empty, ps2_full, ps2_overflow, ps2_frame_error, ps2_shift, ps2_caps;
    wire ps2_rd;

    ps2_keyboard u_ps2(
        .clk(clk),
        .rst(rst_hi),
        .ps2_clk(ps2_clk),
        .ps2_dat(ps2_dat),
        .rd_en(ps2_rd),
        .rd_data(ps2_rdata),
        .empty(ps2_empty),
        .full(ps2_full),
        .overflow(ps2_overflow),
        .frame_error(ps2_frame_error),
        .shift_down(ps2_shift),
        .caps_lock(ps2_caps)
    );

    wire vga_we, vga_busy;
    wire [11:0] vga_addr;
    wire [7:0] vga_wdata, vga_rdata;

    vga_text u_vga(
        .cpu_clk(clk),
        .pix_clk(vga_clk),
        .rst(rst_hi),
        .cpu_we(vga_we),
        .cpu_addr(vga_addr),
        .cpu_wdata(vga_wdata),
        .cpu_rdata(vga_rdata),
        .cpu_busy(vga_busy),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .hsync(vga_hsync),
        .vsync(vga_vsync)
    );

    wire uart_send, uart_busy;
    wire [7:0] uart_data;

    uart_tx_simple u_uart(
        .clk(clk),
        .rst(rst_hi),
        .send(uart_send),
        .data(uart_data),
        .tx(uart_tx),
        .busy(uart_busy)
    );

    assign irq = {5'b0, !ps2_empty, timer[20], 1'b0};

    wire mmio_req_valid = d_req_valid && d_is_mmio && d_req_ready;
    wire mmio_req_ready, mmio_resp_valid, mmio_resp_err;
    wire [31:0] mmio_resp_rdata;
    wire nand_req_valid, nand_req_ready, nand_req_we, nand_resp_valid;
    wire [7:0] nand_req_addr;
    wire [3:0] nand_req_wstrb;
    wire [31:0] nand_req_wdata, nand_resp_rdata;

    mmio_tdm_bus_lite u_mmio(
        .clk(clk),
        .rst(rst_hi),
        .req_valid(mmio_req_valid),
        .req_ready(mmio_req_ready),
        .req_we(d_req_we),
        .req_wstrb(d_req_wstrb),
        .req_addr(d_req_vaddr),
        .req_wdata(d_req_wdata),
        .resp_valid(mmio_resp_valid),
        .resp_ready(!d_resp_valid || d_resp_ready),
        .resp_rdata(mmio_resp_rdata),
        .resp_err(mmio_resp_err),
        .ps2_empty(ps2_empty),
        .ps2_full(ps2_full),
        .ps2_overflow(ps2_overflow),
        .ps2_shift(ps2_shift),
        .ps2_caps_lock(ps2_caps),
        .ps2_rdata(ps2_rdata),
        .ps2_rd(ps2_rd),
        .vga_we(vga_we),
        .vga_addr(vga_addr),
        .vga_wdata(vga_wdata),
        .vga_rdata(vga_rdata),
        .vga_busy(vga_busy),
        .timer_value(timer),
        .uart_send(uart_send),
        .uart_data(uart_data),
        .uart_busy(uart_busy),
        .nand_req_valid(nand_req_valid),
        .nand_req_ready(nand_req_ready),
        .nand_req_we(nand_req_we),
        .nand_req_addr(nand_req_addr),
        .nand_req_wstrb(nand_req_wstrb),
        .nand_req_wdata(nand_req_wdata),
        .nand_resp_valid(nand_resp_valid),
        .nand_resp_rdata(nand_resp_rdata),
        .led_value(led_value),
        .diag_value(diag_value)
    );

    nand_ctrl_readonly u_nand(
        .clk(clk),
        .rst(rst_hi),
        .mmio_req_ready(nand_req_ready),
        .mmio_req_valid(nand_req_valid),
        .mmio_req_we(nand_req_we),
        .mmio_req_addr(nand_req_addr),
        .mmio_req_wstrb(nand_req_wstrb),
        .mmio_req_wdata(nand_req_wdata),
        .mmio_resp_valid(nand_resp_valid),
        .mmio_resp_ready(1'b1),
        .mmio_resp_rdata(nand_resp_rdata),
        .nand_d(nand_d),
        .nand_cle(nand_cle),
        .nand_ale(nand_ale),
        .nand_ce_n(nand_ce_n),
        .nand_re_n(nand_re_n),
        .nand_we_n(nand_we_n),
        .nand_wp_n(nand_wp_n),
        .nand_rdy(nand_rdy)
    );

    ddr3_mig_bridge u_ddr3_bridge(
        .sys_clk_i(ddr_sys_clk_i),
        .sys_rst(rst_hi),
        .ui_clk(ddr_ui_clk),
        .ui_rst(ddr_ui_rst),
        .init_calib_complete(ddr_init_calib_complete),
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
        .ddr3_odt(ddr3_odt),
        .cpu_req_valid(ddr_req_valid),
        .cpu_req_ready(ddr_req_ready),
        .cpu_req_we(ddr_req_we),
        .cpu_req_wstrb(ddr_req_wstrb),
        .cpu_req_addr(ddr_req_addr),
        .cpu_req_wdata(ddr_req_wdata),
        .cpu_resp_valid(ddr_resp_valid),
        .cpu_resp_ready(ddr_resp_ready),
        .cpu_resp_rdata(ddr_resp_rdata)
    );

    assign i_req_ready = i_ddr_sel && ddr_req_ready;
    assign d_req_ready = d_req_valid &&
                         (d_is_mmio ? mmio_req_ready : (d_ddr_sel && ddr_req_ready));

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            i_resp_valid <= 1'b0;
            d_resp_valid <= 1'b0;
            timer <= 32'h0;
            i_resp_inst <= 32'h0340_0000;
            d_resp_rdata <= 32'h0;
            i_resp_exc_valid <= 1'b0;
            d_resp_exc_valid <= 1'b0;
            i_resp_ecode <= 6'h0;
            d_resp_ecode <= 6'h0;
            i_resp_badv <= 32'h0;
            d_resp_badv <= 32'h0;
            ddr_resp_is_d <= 1'b0;
            ddr_resp_badv <= 32'h0;
        end else begin
            timer <= timer + 32'd1;

            if (i_resp_valid && i_resp_ready)
                i_resp_valid <= 1'b0;
            if (d_resp_valid && d_resp_ready)
                d_resp_valid <= 1'b0;

            if (ddr_req_fire) begin
                ddr_resp_is_d <= d_ddr_sel;
                ddr_resp_badv <= ddr_req_addr;
            end

            if (mmio_resp_valid && (!d_resp_valid || d_resp_ready)) begin
                d_resp_valid <= 1'b1;
                d_resp_rdata <= mmio_resp_rdata;
                d_resp_exc_valid <= mmio_resp_err;
                d_resp_ecode <= 6'd8;
                d_resp_badv <= d_req_vaddr;
            end

            if (ddr_resp_valid && ddr_resp_ready) begin
                if (ddr_resp_is_d) begin
                    d_resp_valid <= 1'b1;
                    d_resp_rdata <= ddr_resp_rdata;
                    d_resp_exc_valid <= 1'b0;
                    d_resp_ecode <= 6'h0;
                    d_resp_badv <= ddr_resp_badv;
                end else begin
                    i_resp_valid <= 1'b1;
                    i_resp_inst <= ddr_resp_rdata;
                    i_resp_exc_valid <= 1'b0;
                    i_resp_ecode <= 6'h0;
                    i_resp_badv <= ddr_resp_badv;
                end
            end
        end
    end
endmodule

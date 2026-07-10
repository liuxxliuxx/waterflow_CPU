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
    output wire i_resp_err,
    output wire resp_exc_valid,
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
    output wire d_resp_err,
    input wire periph_enable,
    input wire boot_req_valid,
    output wire boot_req_ready,
    input wire [31:0] boot_req_addr,
    input wire [31:0] boot_req_wdata,
    output wire boot_resp_valid,
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
    reg i_resp_exc;
    reg d_resp_exc;
    reg bridge_resp_is_i;
    reg bridge_resp_is_boot;
    reg bridge_resp_is_write;

    wire rst_hi = !rst;

    localparam [31:0] NOP_INST = 32'h0340_0000;

    function is_mmio_addr;
        input [31:0] addr;
        begin
            is_mmio_addr =
                (addr[31:16] == 16'h1fe0) ||
                (addr[31:16] == 16'h1fe1) ||
                (addr[31:16] == 16'h1fe2) ||
                (addr[31:16] == 16'h1fe3) ||
                (addr[31:16] == 16'h1fe6) ||
                (addr[31:16] == 16'h1fd0);
        end
    endfunction

    function is_mem_addr;
        input [31:0] addr;
        begin
            is_mem_addr = (addr[31:29] == 3'b000) && (addr[28:24] != 5'h1f);
        end
    endfunction

    wire i_addr_is_mem = is_mem_addr(i_req_vaddr);
    wire d_addr_is_mem = is_mem_addr(d_req_vaddr);
    wire d_is_mmio = is_mmio_addr(d_req_vaddr);
    wire i_addr_exc = !i_addr_is_mem || (i_req_vaddr[1:0] != 2'b00);
    wire d_addr_unaligned =
        ((d_req_size == 2'b01) && d_req_vaddr[0]) ||
        ((d_req_size == 2'b10) && (d_req_vaddr[1:0] != 2'b00));
    wire d_addr_exc =
        !(d_addr_is_mem || d_is_mmio) ||
        d_addr_unaligned;

    wire i_resp_room = !i_resp_valid || i_resp_ready;
    wire d_resp_room = !d_resp_valid || d_resp_ready;

    wire i_cache_req_valid = i_req_valid && !i_addr_exc && i_resp_room;
    wire i_cache_req_ready;
    wire i_cache_resp_valid;
    wire i_cache_resp_ready = i_resp_room;
    wire [31:0] i_cache_resp_inst;
    wire i_cache_mem_req_valid;
    wire i_cache_mem_req_ready;
    wire [31:0] i_cache_mem_req_addr;
    wire i_cache_mem_resp_valid;
    wire [31:0] i_cache_mem_resp_rdata;

    wire d_cache_req_valid = d_req_valid && !d_addr_exc && !d_is_mmio && d_resp_room;
    wire d_cache_req_ready;
    wire d_cache_resp_valid;
    wire d_cache_resp_ready = d_resp_room;
    wire [31:0] d_cache_resp_rdata;
    wire d_cache_mem_req_valid;
    wire d_cache_mem_req_ready;
    wire d_cache_mem_req_we;
    wire [3:0] d_cache_mem_req_wstrb;
    wire [31:0] d_cache_mem_req_addr;
    wire [31:0] d_cache_mem_req_wdata;
    wire d_cache_mem_resp_valid;
    wire [31:0] d_cache_mem_resp_rdata;

    // The boot loader owns DDR before the CPU is released.  It is deliberately
    // first in this arbitration so an accidental CPU request cannot delay boot.
    wire boot_mem_sel = boot_req_valid;
    wire d_cache_mem_sel = d_cache_mem_req_valid && !boot_mem_sel;
    wire i_cache_mem_sel = i_cache_mem_req_valid &&
                           !boot_mem_sel && !d_cache_mem_sel;
    wire bridge_req_valid = boot_mem_sel || d_cache_mem_sel || i_cache_mem_sel;
    wire bridge_req_ready;
    wire bridge_req_fire = bridge_req_valid && bridge_req_ready;
    wire bridge_req_we = boot_mem_sel ? 1'b1 :
                         (d_cache_mem_sel ? d_cache_mem_req_we : 1'b0);
    wire [3:0] bridge_req_wstrb = boot_mem_sel ? 4'b1111 :
                                 (d_cache_mem_sel ? d_cache_mem_req_wstrb : 4'b0000);
    wire [31:0] bridge_req_addr = boot_mem_sel ? boot_req_addr :
                                  (d_cache_mem_sel ? d_cache_mem_req_addr : i_cache_mem_req_addr);
    wire [31:0] bridge_req_wdata = boot_mem_sel ? boot_req_wdata :
                                   (d_cache_mem_sel ? d_cache_mem_req_wdata : 32'h0);
    wire bridge_resp_valid;
    wire [31:0] bridge_resp_rdata;

    assign d_cache_mem_req_ready = d_cache_mem_sel && bridge_req_ready;
    assign i_cache_mem_req_ready = i_cache_mem_sel && bridge_req_ready;
    assign boot_req_ready = boot_mem_sel && bridge_req_ready;
    assign boot_resp_valid = bridge_resp_valid && bridge_resp_is_boot;
    assign d_cache_mem_resp_valid = bridge_resp_valid && !bridge_resp_is_i &&
                                    !bridge_resp_is_boot && !bridge_resp_is_write;
    assign i_cache_mem_resp_valid = bridge_resp_valid && bridge_resp_is_i && !bridge_resp_is_write;
    assign d_cache_mem_resp_rdata = bridge_resp_rdata;
    assign i_cache_mem_resp_rdata = bridge_resp_rdata;

    wire mmio_req_valid = d_req_valid && !d_addr_exc && d_is_mmio &&
                          d_resp_room && periph_enable;
    wire mmio_req_ready, mmio_resp_valid, mmio_resp_err;
    wire mmio_resp_ready = d_resp_room && !d_cache_resp_valid;
    wire [31:0] mmio_resp_rdata;

    wire i_resp_incoming = i_cache_resp_valid;
    wire d_resp_incoming = d_cache_resp_valid || mmio_resp_valid;
    wire i_accept_room = i_resp_room && !i_resp_incoming;
    wire d_accept_room = d_resp_room && !d_resp_incoming;
    wire i_exc_req_fire = i_req_valid && i_accept_room && i_addr_exc;
    wire d_exc_req_fire = d_req_valid && d_accept_room && d_addr_exc;

    mmio_tdm_bus u_mmio(
        .clk(clk),
        .rst(rst_hi || !periph_enable),
        .req_valid(mmio_req_valid),
        .req_ready(mmio_req_ready),
        .req_we(d_req_we),
        .req_wstrb(d_req_wstrb),
        .req_addr(d_req_vaddr),
        .req_wdata(d_req_wdata),
        .resp_valid(mmio_resp_valid),
        .resp_ready(mmio_resp_ready),
        .resp_rdata(mmio_resp_rdata),
        .resp_err(mmio_resp_err),
        .ps2_clk(ps2_clk),
        .ps2_dat(ps2_dat),
        .vga_clk(vga_clk),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .irq(irq),
        .timer_value(timer),
        .nand_d(nand_d),
        .nand_cle(nand_cle),
        .nand_ale(nand_ale),
        .nand_ce_n(nand_ce_n),
        .nand_re_n(nand_re_n),
        .nand_we_n(nand_we_n),
        .nand_wp_n(nand_wp_n),
        .nand_rdy(nand_rdy),
        .led_value(led_value),
        .diag_value(diag_value)
    );

    icache_blocking u_icache(
        .clk(clk),
        .rst(rst),
        .req_valid(i_cache_req_valid),
        .req_ready(i_cache_req_ready),
        .req_addr(i_req_vaddr),
        .resp_valid(i_cache_resp_valid),
        .resp_ready(i_cache_resp_ready),
        .resp_inst(i_cache_resp_inst),
        .mem_req_valid(i_cache_mem_req_valid),
        .mem_req_ready(i_cache_mem_req_ready),
        .mem_req_addr(i_cache_mem_req_addr),
        .mem_resp_valid(i_cache_mem_resp_valid),
        .mem_resp_rdata(i_cache_mem_resp_rdata)
    );

    dcache_blocking_lite u_dcache(
        .clk(clk),
        .rst(rst),
        .req_valid(d_cache_req_valid),
        .req_ready(d_cache_req_ready),
        .req_we(d_req_we),
        .req_size(d_req_size),
        .req_wstrb(d_req_wstrb),
        .req_addr(d_req_vaddr),
        .req_wdata(d_req_wdata),
        .resp_valid(d_cache_resp_valid),
        .resp_ready(d_cache_resp_ready),
        .resp_rdata(d_cache_resp_rdata),
        .mem_req_valid(d_cache_mem_req_valid),
        .mem_req_ready(d_cache_mem_req_ready),
        .mem_req_we(d_cache_mem_req_we),
        .mem_req_wstrb(d_cache_mem_req_wstrb),
        .mem_req_addr(d_cache_mem_req_addr),
        .mem_req_wdata(d_cache_mem_req_wdata),
        .mem_resp_valid(d_cache_mem_resp_valid),
        .mem_resp_rdata(d_cache_mem_resp_rdata)
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
        .cpu_req_valid(bridge_req_valid),
        .cpu_req_ready(bridge_req_ready),
        .cpu_req_we(bridge_req_we),
        .cpu_req_wstrb(bridge_req_wstrb),
        .cpu_req_addr(bridge_req_addr),
        .cpu_req_wdata(bridge_req_wdata),
        .cpu_resp_valid(bridge_resp_valid),
        .cpu_resp_ready(1'b1),
        .cpu_resp_rdata(bridge_resp_rdata)
    );

    assign resp_exc_valid = (i_resp_valid && i_resp_exc) ||
                            (d_resp_valid && d_resp_exc);
    assign i_resp_err = i_resp_exc;
    assign d_resp_err = d_resp_exc;

    assign i_req_ready = i_resp_room &&
                         (i_addr_exc ? !i_resp_incoming : i_cache_req_ready);
    assign d_req_ready = d_req_valid && d_resp_room &&
                         (d_addr_exc ? !d_resp_incoming :
                          (d_is_mmio ? (periph_enable && !d_cache_resp_valid && mmio_req_ready) :
                                       d_cache_req_ready));

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            i_resp_valid <= 1'b0;
            d_resp_valid <= 1'b0;
            timer <= 32'h0;
            i_resp_inst <= NOP_INST;
            d_resp_rdata <= 32'h0;
            i_resp_exc <= 1'b0;
            d_resp_exc <= 1'b0;
            bridge_resp_is_i <= 1'b0;
            bridge_resp_is_boot <= 1'b0;
            bridge_resp_is_write <= 1'b0;
        end else begin
            timer <= timer + 32'd1;

            if (i_resp_valid && i_resp_ready) begin
                i_resp_valid <= 1'b0;
                i_resp_exc <= 1'b0;
            end
            if (d_resp_valid && d_resp_ready) begin
                d_resp_valid <= 1'b0;
                d_resp_exc <= 1'b0;
            end

            if (bridge_req_fire) begin
                bridge_resp_is_i <= i_cache_mem_sel;
                bridge_resp_is_boot <= boot_mem_sel;
                bridge_resp_is_write <= bridge_req_we;
            end

            if (i_exc_req_fire) begin
                i_resp_valid <= 1'b1;
                i_resp_inst <= NOP_INST;
                i_resp_exc <= 1'b1;
            end

            if (d_exc_req_fire) begin
                d_resp_valid <= 1'b1;
                d_resp_rdata <= 32'h0;
                d_resp_exc <= 1'b1;
            end

            if (mmio_resp_valid && mmio_resp_ready) begin
                d_resp_valid <= 1'b1;
                d_resp_rdata <= mmio_resp_rdata;
                d_resp_exc <= mmio_resp_err;
            end

            if (i_cache_resp_valid && i_cache_resp_ready) begin
                i_resp_valid <= 1'b1;
                i_resp_inst <= i_cache_resp_inst;
                i_resp_exc <= 1'b0;
            end

            if (d_cache_resp_valid && d_cache_resp_ready) begin
                d_resp_valid <= 1'b1;
                d_resp_rdata <= d_cache_resp_rdata;
                d_resp_exc <= 1'b0;
            end
        end
    end
endmodule

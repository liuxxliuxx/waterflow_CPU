`timescale 1ns / 1ps

module soc_top #(
    parameter [24:0] BOOT_NAND_START_WORD = 25'd0,
    parameter [31:0] BOOT_WORDS = 32'd1024,
    parameter [31:0] BOOT_LOAD_ADDR = 32'h1c00_0000
) (
    input  wire        sys_clk_i,
    input  wire        rst_n,

    output wire        uart_tx,
    input  wire        uart_rx,
    output wire [7:0]  led,

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
    wire soc_clk_25;
    wire cpu_rst_n;
    reg [1:0] ddr_ready_sync;
    wire ddr_ready_25 = ddr_ready_sync[1];

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

    wire boot_ddr_req_valid;
    wire boot_ddr_req_ready;
    wire [31:0] boot_ddr_req_addr;
    wire [31:0] boot_ddr_req_wdata;
    wire boot_ddr_resp_valid;
    wire boot_done;
    wire boot_error;

    wire [7:0] irq;
    wire [7:0] mmio_led_value;
    wire [31:0] diag_value;
    wire [3:0] unused_vga_r;
    wire [3:0] unused_vga_g;
    wire [3:0] unused_vga_b;
    wire unused_vga_hsync;
    wire unused_vga_vsync;

    wire [7:0] nand_boot_d_o;
    wire nand_boot_d_oe;
    wire nand_boot_cle, nand_boot_ale, nand_boot_ce_n;
    wire nand_boot_re_n, nand_boot_we_n, nand_boot_wp_n;
    wire nand_mmio_cle, nand_mmio_ale, nand_mmio_ce_n;
    wire nand_mmio_re_n, nand_mmio_we_n, nand_mmio_wp_n;
    wire nand_wp_unused;
    wire nand_boot_owner = !boot_done;

    // mem_subsystem keeps its MMIO fabric reset until boot_done, so its NAND
    // driver is high impedance while the boot loader owns the physical bus.
    assign nand_d = (nand_boot_owner && nand_boot_d_oe) ? nand_boot_d_o : 8'hzz;
    assign nand_cle  = nand_boot_owner ? nand_boot_cle  : nand_mmio_cle;
    assign nand_ale  = nand_boot_owner ? nand_boot_ale  : nand_mmio_ale;
    assign nand_ce_n = nand_boot_owner ? nand_boot_ce_n : nand_mmio_ce_n;
    assign nand_re_n = nand_boot_owner ? nand_boot_re_n : nand_mmio_re_n;
    assign nand_we_n = nand_boot_owner ? nand_boot_we_n : nand_mmio_we_n;
    // The board pulls NAND WP# high externally; this SoC only performs reads.
    assign nand_wp_unused = nand_boot_owner ? nand_boot_wp_n : nand_mmio_wp_n;

    // Synchronize MIG readiness into the 25 MHz SoC domain before using it
    // for reset release or the boot loader's first DDR request.
    always @(posedge soc_clk_25 or negedge rst_n) begin
        if (!rst_n) begin
            ddr_ready_sync <= 2'b00;
        end else begin
            ddr_ready_sync <= {ddr_ready_sync[0],
                               ddr_init_calib_complete && !ddr_ui_rst};
        end
    end

    assign cpu_rst_n = rst_n && ddr_ready_25 && boot_done;

    // sys_clk_i is the 100 MHz board clock. CPU, caches, MMIO, NAND boot, and
    // VGA run at this divide-by-four 25 MHz clock; only MIG remains at UI clk.
    soc_vga_clk_div u_vga_clk_div (
        .clk(sys_clk_i),
        .rst_n(rst_n),
        .clk_out(soc_clk_25)
    );

    nand_boot_loader #(
        .BOOT_NAND_START_WORD(BOOT_NAND_START_WORD),
        .BOOT_WORDS(BOOT_WORDS),
        .BOOT_LOAD_ADDR(BOOT_LOAD_ADDR)
    ) u_boot_loader (
        .clk(soc_clk_25),
        .rst_n(rst_n),
        .ddr_ready(ddr_ready_25),
        .ddr_req_valid(boot_ddr_req_valid),
        .ddr_req_ready(boot_ddr_req_ready),
        .ddr_req_addr(boot_ddr_req_addr),
        .ddr_req_wdata(boot_ddr_req_wdata),
        .ddr_resp_valid(boot_ddr_resp_valid),
        .nand_d_i(nand_d),
        .nand_d_o(nand_boot_d_o),
        .nand_d_oe(nand_boot_d_oe),
        .nand_cle(nand_boot_cle),
        .nand_ale(nand_boot_ale),
        .nand_ce_n(nand_boot_ce_n),
        .nand_re_n(nand_boot_re_n),
        .nand_we_n(nand_boot_we_n),
        .nand_wp_n(nand_boot_wp_n),
        .nand_rdy(nand_rdy),
        .boot_done(boot_done),
        .boot_error(boot_error)
    );

    CPU u_cpu (
        .clk(soc_clk_25),
        .rst(cpu_rst_n),
        .test_addr(5'd0),
        .test_data(),
        .test_pc_cur(),
        .test_inst(),
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

    mem_subsystem u_mem_subsystem (
        .clk(soc_clk_25),
        .rst(rst_n),
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
        .periph_enable(boot_done),
        .boot_req_valid(boot_ddr_req_valid),
        .boot_req_ready(boot_ddr_req_ready),
        .boot_req_addr(boot_ddr_req_addr),
        .boot_req_wdata(boot_ddr_req_wdata),
        .boot_resp_valid(boot_ddr_resp_valid),
        .ps2_clk(1'b1),
        .ps2_dat(1'b1),
        .vga_clk(soc_clk_25),
        .vga_r(unused_vga_r),
        .vga_g(unused_vga_g),
        .vga_b(unused_vga_b),
        .vga_hsync(unused_vga_hsync),
        .vga_vsync(unused_vga_vsync),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .irq(irq),
        .led_value(mmio_led_value),
        .diag_value(diag_value),
        .nand_d(nand_d),
        .nand_cle(nand_mmio_cle),
        .nand_ale(nand_mmio_ale),
        .nand_ce_n(nand_mmio_ce_n),
        .nand_re_n(nand_mmio_re_n),
        .nand_we_n(nand_mmio_we_n),
        .nand_wp_n(nand_mmio_wp_n),
        .nand_rdy(nand_rdy),
        .ddr_sys_clk_i(sys_clk_i),
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

    // Board LEDs are active low. Before software takes ownership, expose
    // mutually exclusive boot stages so a solid all-on pattern means that
    // boot completed but software has not yet written the LED register.
    //   8'hfe: LED0 on, waiting for DDR calibration
    //   8'hfd: LED1 on, NAND image loading
    //   8'hfb: LED2 on, boot failure
    assign led = boot_error ? 8'hfb :
                 (boot_done ? mmio_led_value :
                              (ddr_ready_25 ? 8'hfd : 8'hfe));
endmodule

module soc_vga_clk_div (
    input wire clk,
    input wire rst_n,
    output wire clk_out
);
    reg [1:0] div_count;
    reg pix_clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_count <= 2'd0;
            pix_clk <= 1'b0;
        end else if (div_count == 2'd1) begin
            div_count <= 2'd0;
            pix_clk <= ~pix_clk;
        end else begin
            div_count <= div_count + 2'd1;
        end
    end

    BUFG u_pix_clk_bufg (
        .I(pix_clk),
        .O(clk_out)
    );
endmodule

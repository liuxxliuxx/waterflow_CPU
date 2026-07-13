`timescale 1ns / 1ps

module mmio_tdm_bus #(
    parameter [24:0] BOOT_NAND_START_WORD = 25'd0,
    parameter [31:0] BOOT_LOAD_ADDR = 32'h1c00_0000,
    parameter [31:0] BOOT_MAX_PAYLOAD_BYTES = 32'd8386560
) (
    input wire clk,
    input wire rst,
    input wire req_valid,
    output wire req_ready,
    input wire req_we,
    input wire [3:0] req_wstrb,
    input wire [31:0] req_addr,
    input wire [31:0] req_wdata,
    output reg resp_valid,
    input wire resp_ready,
    output reg [31:0] resp_rdata,
    output reg resp_err,
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
    input wire [31:0] timer_value,
    input wire boot_ddr_ready,
    output wire boot_req_valid,
    input wire boot_req_ready,
    output wire boot_req_we,
    output wire [3:0] boot_req_wstrb,
    output wire [31:0] boot_req_addr,
    output wire [31:0] boot_req_wdata,
    input wire boot_resp_valid,
    input wire [31:0] boot_resp_rdata,
    output wire boot_done,
    output wire boot_error,
    output wire [31:0] boot_status,
    inout wire [7:0] nand_d,
    output wire nand_cle,
    output wire nand_ale,
    output wire nand_ce_n,
    output wire nand_re_n,
    output wire nand_we_n,
    output wire nand_wp_n,
    input wire nand_rdy,
    output wire [15:0] led,
    output wire [7:0] seg_csn,
    output wire [7:0] seg
);
    localparam S_IDLE      = 2'd0,
               S_NAND_WAIT = 2'd1,
               S_VGA_RESP  = 2'd2,
               S_VGA_WAIT  = 2'd3;

    reg [1:0] state;
    reg [2:0] slot;
    reg vga_wait_req;
    reg [15:0] led_value;
    reg [31:0] seg_pattern_lo;
    reg [31:0] seg_pattern_hi;
    reg [7:0] seg_enable;
    reg boot_done_d;
    reg [22:0] boot_display_hold_count;
    reg nand_req_valid;
    wire nand_req_ready;
    reg nand_req_we;
    reg [7:0] nand_req_addr;
    reg [3:0] nand_req_wstrb;
    reg [31:0] nand_req_wdata;
    wire nand_resp_valid;
    wire [31:0] nand_resp_rdata;
    wire nand_resp_err;

    localparam [22:0] BOOT_DISPLAY_HOLD_CYCLES = 23'd6_250_000;

    function [7:0] hex_segments;
        input [3:0] value;
        begin
            case (value)
                4'h0: hex_segments = 8'h3f;
                4'h1: hex_segments = 8'h06;
                4'h2: hex_segments = 8'h5b;
                4'h3: hex_segments = 8'h4f;
                4'h4: hex_segments = 8'h66;
                4'h5: hex_segments = 8'h6d;
                4'h6: hex_segments = 8'h7d;
                4'h7: hex_segments = 8'h07;
                4'h8: hex_segments = 8'h7f;
                4'h9: hex_segments = 8'h6f;
                4'ha: hex_segments = 8'h77;
                4'hb: hex_segments = 8'h7c;
                4'hc: hex_segments = 8'h39;
                4'hd: hex_segments = 8'h5e;
                4'he: hex_segments = 8'h79;
                default: hex_segments = 8'h71;
            endcase
        end
    endfunction

    wire boot_display_active = !boot_done || (boot_display_hold_count != 23'd0);
    wire [31:0] boot_seg_pattern_lo = {
        hex_segments(boot_status[19:16]), hex_segments(boot_status[23:20]),
        hex_segments(boot_status[27:24]), hex_segments(boot_status[31:28])
    };
    wire [31:0] boot_seg_pattern_hi = {
        hex_segments(boot_status[3:0]), hex_segments(boot_status[7:4]),
        hex_segments(boot_status[11:8]), hex_segments(boot_status[15:12])
    };
    wire [31:0] active_seg_pattern_lo = boot_display_active ? boot_seg_pattern_lo : seg_pattern_lo;
    wire [31:0] active_seg_pattern_hi = boot_display_active ? boot_seg_pattern_hi : seg_pattern_hi;
    wire [7:0] active_seg_enable = boot_display_active ? 8'hff : seg_enable;

    assign led = ~led_value;

    sevenseg_scan u_sevenseg_scan (
        .clk(clk),
        .rst(rst),
        .pattern_lo(active_seg_pattern_lo),
        .pattern_hi(active_seg_pattern_hi),
        .enable(active_seg_enable),
        .seg_csn(seg_csn),
        .seg(seg)
    );

    wire [7:0] ps2_rdata;
    wire ps2_empty, ps2_full, ps2_overflow, ps2_frame_error;
    reg ps2_rd;
    reg ps2_clear_errors;

    reg vga_we;
    wire vga_busy;
    reg [13:0] vga_addr;
    reg [31:0] vga_wdata;
    reg [3:0] vga_wstrb;
    wire [31:0] vga_rdata;

    reg uart_send;
    wire uart_busy;
    reg [7:0] uart_data;


    wire dev_ps2   = (req_addr[31:16] == 16'h1fe0);
    wire dev_vga   = (req_addr[31:16] == 16'h1fe1);
    wire dev_timer = (req_addr[31:16] == 16'h1fe2);
    wire dev_uart  = (req_addr[31:16] == 16'h1fe3);
    wire dev_seg   = (req_addr[31:16] == 16'h1fe5);
    wire dev_nand  = (req_addr[31:16] == 16'h1fd0);
    wire dev_led   = (req_addr[31:16] == 16'h1fe6);
    wire [15:0] req_offset = req_addr[15:0];
    wire [13:0] vga_word_addr = req_addr[15:2];
    wire ps2_addr_valid = (req_offset == 16'h0000) ||
                           (req_offset == 16'h0004) ||
                           (req_offset == 16'h0008);
    wire vga_addr_valid = (vga_word_addr < 14'd2400) ||
                          (vga_word_addr == 14'h0fff) ||
                          ((vga_word_addr >= 14'h1000) &&
                           (vga_word_addr <= 14'h1003));
    wire timer_addr_valid = (req_offset == 16'h0000);
    wire uart_addr_valid = (req_offset == 16'h0000);
    wire nand_addr_valid = (req_offset == 16'h0000) ||
                           (req_offset == 16'h0004) ||
                           (req_offset == 16'h0008);
    wire seg_addr_valid = (req_offset == 16'h0000) ||
                          (req_offset == 16'h0004) ||
                          (req_offset == 16'h0008) ||
                          (req_offset == 16'h000c);
    wire led_addr_valid = (req_offset == 16'h0000);

    wire slot_match =
        (dev_ps2 && slot == 3'd0) ||
        (dev_vga && slot == 3'd1) ||
        (dev_timer && slot == 3'd2) ||
        (dev_uart && slot == 3'd3) ||
        (dev_nand && slot == 3'd4) ||
        (dev_seg && slot == 3'd5) ||
        (dev_led && slot == 3'd7);

    assign req_ready = (state == S_IDLE) && (!resp_valid || resp_ready) &&
                       slot_match &&
                       (!dev_vga || !vga_busy || !vga_addr_valid) &&
                       (!dev_nand || nand_req_ready || !nand_addr_valid);

    assign irq = {5'b0, !ps2_empty, timer_value[20], 1'b0};

    ps2_keyboard u_ps2(
        .clk(clk),
        .rst(rst),
        .ps2_clk(ps2_clk),
        .ps2_dat(ps2_dat),
        .rd_en(ps2_rd),
        .clear_errors(ps2_clear_errors),
        .rd_data(ps2_rdata),
        .empty(ps2_empty),
        .full(ps2_full),
        .overflow(ps2_overflow),
        .frame_error(ps2_frame_error)
    );

    vga_text u_vga(
        .cpu_clk(clk),
        .pix_clk(vga_clk),
        .rst(rst),
        .cpu_we(vga_we),
        .cpu_addr(vga_addr),
        .cpu_wdata(vga_wdata),
        .cpu_wstrb(vga_wstrb),
        .cpu_rdata(vga_rdata),
        .cpu_busy(vga_busy),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .hsync(vga_hsync),
        .vsync(vga_vsync)
    );

    uart_tx_simple u_uart(
        .clk(clk),
        .rst(rst),
        .send(uart_send),
        .data(uart_data),
        .tx(uart_tx),
        .busy(uart_busy)
    );

    nand_controller #(
        .BOOT_NAND_START_WORD(BOOT_NAND_START_WORD),
        .BOOT_LOAD_ADDR(BOOT_LOAD_ADDR),
        .BOOT_MAX_PAYLOAD_BYTES(BOOT_MAX_PAYLOAD_BYTES)
    ) u_nand_controller (
        .clk(clk),
        .rst_n(!rst),
        .boot_ddr_ready(boot_ddr_ready),
        .boot_req_valid(boot_req_valid),
        .boot_req_ready(boot_req_ready),
        .boot_req_we(boot_req_we),
        .boot_req_wstrb(boot_req_wstrb),
        .boot_req_addr(boot_req_addr),
        .boot_req_wdata(boot_req_wdata),
        .boot_resp_valid(boot_resp_valid),
        .boot_resp_rdata(boot_resp_rdata),
        .boot_done(boot_done),
        .boot_error(boot_error),
        .boot_status(boot_status),
        .mmio_req_ready(nand_req_ready),
        .mmio_req_valid(nand_req_valid),
        .mmio_req_we(nand_req_we),
        .mmio_req_addr(nand_req_addr),
        .mmio_req_wstrb(nand_req_wstrb),
        .mmio_req_wdata(nand_req_wdata),
        .mmio_resp_valid(nand_resp_valid),
        .mmio_resp_ready(1'b1),
        .mmio_resp_rdata(nand_resp_rdata),
        .mmio_resp_err(nand_resp_err),
        .nand_d(nand_d),
        .nand_cle(nand_cle),
        .nand_ale(nand_ale),
        .nand_ce_n(nand_ce_n),
        .nand_re_n(nand_re_n),
        .nand_we_n(nand_we_n),
        .nand_wp_n(nand_wp_n),
        .nand_rdy(nand_rdy)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            slot <= 3'd0;
            resp_valid <= 1'b0;
            resp_rdata <= 32'h0;
            resp_err <= 1'b0;
            ps2_rd <= 1'b0;
            ps2_clear_errors <= 1'b0;
            vga_we <= 1'b0;
            vga_addr <= 14'h0;
            vga_wdata <= 32'h0;
            vga_wstrb <= 4'h0;
            vga_wait_req <= 1'b0;
            uart_send <= 1'b0;
            uart_data <= 8'h0;
            nand_req_valid <= 1'b0;
            nand_req_we <= 1'b0;
            nand_req_addr <= 8'h0;
            nand_req_wstrb <= 4'h0;
            nand_req_wdata <= 32'h0;
            led_value <= 16'h0000;
            seg_pattern_lo <= 32'h0000_0000;
            seg_pattern_hi <= 32'h0000_0000;
            seg_enable <= 8'h00;
            boot_done_d <= 1'b0;
            boot_display_hold_count <= 23'd0;
        end else begin
            boot_done_d <= boot_done;
            if (boot_done && !boot_done_d)
                boot_display_hold_count <= BOOT_DISPLAY_HOLD_CYCLES;
            else if (boot_display_hold_count != 23'd0)
                boot_display_hold_count <= boot_display_hold_count - 23'd1;
            slot <= slot + 3'd1;
            ps2_rd <= 1'b0;
            ps2_clear_errors <= 1'b0;
            vga_we <= 1'b0;
            uart_send <= 1'b0;
            nand_req_valid <= 1'b0;

            if (resp_valid && resp_ready) begin
                resp_valid <= 1'b0;
                resp_err <= 1'b0;
            end

            case (state)
                S_IDLE: begin
                    if (req_valid && req_ready) begin
                        resp_rdata <= 32'h0;
                        resp_err <= 1'b0;

                        if (dev_ps2) begin
                            if (!ps2_addr_valid) begin
                                resp_err <= 1'b1;
                            end else if (req_offset == 16'h0000) begin
                                if (req_we)
                                    resp_err <= 1'b1;
                                resp_rdata <= {28'h0, ps2_frame_error,
                                               ps2_overflow, ps2_full, ps2_empty};
                            end else if (req_offset == 16'h0004) begin
                                resp_rdata <= {24'h0, ps2_rdata};
                                if (req_we)
                                    resp_err <= 1'b1;
                                else
                                    ps2_rd <= !ps2_empty;
                            end else if (req_offset == 16'h0008) begin
                                if (!req_we)
                                    resp_err <= 1'b1;
                                else if (|req_wstrb)
                                    ps2_clear_errors <= 1'b1;
                            end
                            resp_valid <= 1'b1;
                        end else if (dev_vga) begin
                            if (!vga_addr_valid) begin
                                resp_err <= 1'b1;
                                resp_valid <= 1'b1;
                            end else begin
                                vga_addr <= vga_word_addr;
                                vga_wdata <= req_wdata;
                                vga_wstrb <= req_wstrb;
                                vga_we <= req_we;
                                vga_wait_req <= req_we &&
                                                ((vga_word_addr == 14'h0fff) ||
                                                 (vga_word_addr == 14'h1003));
                                state <= S_VGA_RESP;
                            end
                        end else if (dev_timer) begin
                            if (!timer_addr_valid)
                                resp_err <= 1'b1;
                            else
                                resp_rdata <= timer_value;
                            resp_valid <= 1'b1;
                        end else if (dev_uart) begin
                            if (!uart_addr_valid) begin
                                resp_err <= 1'b1;
                            end else if (req_we && !uart_busy) begin
                                uart_data <= req_wdata[7:0];
                                uart_send <= 1'b1;
                            end
                            resp_rdata <= {31'h0, uart_busy};
                            resp_valid <= 1'b1;
                        end else if (dev_nand) begin
                            if (!nand_addr_valid) begin
                                resp_err <= 1'b1;
                                resp_valid <= 1'b1;
                            end else begin
                                nand_req_valid <= 1'b1;
                                nand_req_we <= req_we;
                                nand_req_addr <= req_addr[7:0];
                                nand_req_wstrb <= req_wstrb;
                                nand_req_wdata <= req_wdata;
                                state <= S_NAND_WAIT;
                            end
                        end else if (dev_seg) begin
                            if (!seg_addr_valid) begin
                                resp_err <= 1'b1;
                            end else begin
                                case (req_offset)
                                    16'h0000: begin
                                        resp_rdata <= seg_pattern_lo;
                                        if (req_we) begin
                                            if (req_wstrb[0]) seg_pattern_lo[7:0] <= req_wdata[7:0];
                                            if (req_wstrb[1]) seg_pattern_lo[15:8] <= req_wdata[15:8];
                                            if (req_wstrb[2]) seg_pattern_lo[23:16] <= req_wdata[23:16];
                                            if (req_wstrb[3]) seg_pattern_lo[31:24] <= req_wdata[31:24];
                                        end
                                    end
                                    16'h0004: begin
                                        resp_rdata <= seg_pattern_hi;
                                        if (req_we) begin
                                            if (req_wstrb[0]) seg_pattern_hi[7:0] <= req_wdata[7:0];
                                            if (req_wstrb[1]) seg_pattern_hi[15:8] <= req_wdata[15:8];
                                            if (req_wstrb[2]) seg_pattern_hi[23:16] <= req_wdata[23:16];
                                            if (req_wstrb[3]) seg_pattern_hi[31:24] <= req_wdata[31:24];
                                        end
                                    end
                                    16'h0008: begin
                                        resp_rdata <= {24'h0, seg_enable};
                                        if (req_we && req_wstrb[0])
                                            seg_enable <= req_wdata[7:0];
                                    end
                                    default: begin
                                        resp_rdata <= boot_status;
                                        if (req_we)
                                            resp_err <= 1'b1;
                                    end
                                endcase
                            end
                            resp_valid <= 1'b1;
                        end else if (dev_led) begin
                            if (!led_addr_valid) begin
                                resp_err <= 1'b1;
                            end else begin
                                if (req_we) begin
                                    if (req_wstrb[0]) led_value[7:0] <= req_wdata[7:0];
                                    if (req_wstrb[1]) led_value[15:8] <= req_wdata[15:8];
                                end
                                resp_rdata <= {16'h0, led_value};
                            end
                            resp_valid <= 1'b1;
                        end else begin
                            resp_err <= 1'b1;
                            resp_valid <= 1'b1;
                        end
                    end
                end

                S_NAND_WAIT: begin
                    if (nand_resp_valid) begin
                        resp_rdata <= nand_resp_rdata;
                        resp_err <= nand_resp_err;
                        resp_valid <= 1'b1;
                        state <= S_IDLE;
                    end
                end

                S_VGA_RESP: begin
                    if (vga_wait_req) begin
                        state <= S_VGA_WAIT;
                    end else begin
                        resp_rdata <= vga_rdata;
                        resp_err <= 1'b0;
                        resp_valid <= 1'b1;
                        state <= S_IDLE;
                    end
                end

                S_VGA_WAIT: begin
                    if (!vga_busy) begin
                        vga_wait_req <= 1'b0;
                        resp_rdata <= vga_rdata;
                        resp_err <= 1'b0;
                        resp_valid <= 1'b1;
                        state <= S_IDLE;
                    end
                end
            endcase
        end
    end
endmodule

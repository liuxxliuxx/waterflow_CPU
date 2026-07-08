`timescale 1ns / 1ps

module mmio_tdm_bus_lite(
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
    input wire ps2_empty,
    input wire ps2_full,
    input wire ps2_overflow,
    input wire ps2_shift,
    input wire ps2_caps_lock,
    input wire [7:0] ps2_rdata,
    output reg ps2_rd,
    output reg vga_we,
    output reg [11:0] vga_addr,
    output reg [7:0] vga_wdata,
    input wire [7:0] vga_rdata,
    input wire vga_busy,
    input wire [31:0] timer_value,
    output reg uart_send,
    output reg [7:0] uart_data,
    input wire uart_busy,
    output reg nand_req_valid,
    input wire nand_req_ready,
    output reg nand_req_we,
    output reg [7:0] nand_req_addr,
    output reg [3:0] nand_req_wstrb,
    output reg [31:0] nand_req_wdata,
    input wire nand_resp_valid,
    input wire [31:0] nand_resp_rdata,
    output reg [7:0] led_value,
    output reg [31:0] diag_value
);
    localparam S_IDLE      = 2'd0,
               S_NAND_WAIT = 2'd1,
               S_VGA_RESP  = 2'd2,
               S_VGA_WAIT  = 2'd3;

    reg [1:0] state;
    reg [2:0] slot;
    reg vga_wait_req;

    wire dev_ps2   = (req_addr[31:16] == 16'h1fe0);
    wire dev_vga   = (req_addr[31:16] == 16'h1fe1);
    wire dev_timer = (req_addr[31:16] == 16'h1fe2);
    wire dev_uart  = (req_addr[31:16] == 16'h1fe3);
    wire dev_nand  = (req_addr[31:16] == 16'h1fd0);
    wire dev_led   = (req_addr[31:16] == 16'h1fe6);

    wire slot_match =
        (dev_ps2 && slot == 3'd0) ||
        (dev_vga && slot == 3'd1) ||
        (dev_timer && slot == 3'd2) ||
        (dev_uart && slot == 3'd3) ||
        (dev_nand && slot == 3'd4) ||
        (dev_led && slot == 3'd7);

    assign req_ready = (state == S_IDLE) && (!resp_valid || resp_ready) &&
                       slot_match && (!dev_vga || !vga_busy) &&
                       (!dev_nand || nand_req_ready);

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            slot <= 3'd0;
            resp_valid <= 1'b0;
            resp_rdata <= 32'h0;
            resp_err <= 1'b0;
            ps2_rd <= 1'b0;
            vga_we <= 1'b0;
            vga_addr <= 12'h0;
            vga_wdata <= 8'h0;
            vga_wait_req <= 1'b0;
            uart_send <= 1'b0;
            uart_data <= 8'h0;
            nand_req_valid <= 1'b0;
            nand_req_we <= 1'b0;
            nand_req_addr <= 8'h0;
            nand_req_wstrb <= 4'h0;
            nand_req_wdata <= 32'h0;
            led_value <= 8'h00;
            diag_value <= 32'h5555_0000;
        end else begin
            slot <= slot + 3'd1;
            ps2_rd <= 1'b0;
            vga_we <= 1'b0;
            uart_send <= 1'b0;
            nand_req_valid <= 1'b0;
            resp_err <= 1'b0;

            if (resp_valid && resp_ready)
                resp_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (req_valid && req_ready) begin
                        resp_rdata <= 32'h0;

                        if (dev_ps2) begin
                            if (req_addr[7:0] == 8'h00) begin
                                resp_rdata <= {27'h0, ps2_caps_lock, ps2_shift,
                                               ps2_overflow, ps2_full, ps2_empty};
                            end else if (req_addr[7:0] == 8'h04) begin
                                resp_rdata <= {24'h0, ps2_rdata};
                                ps2_rd <= !ps2_empty && !req_we;
                            end
                            resp_valid <= 1'b1;
                        end else if (dev_vga) begin
                            vga_addr <= req_addr[13:2];
                            vga_wdata <= req_wdata[7:0];
                            vga_we <= req_we;
                            vga_wait_req <= req_we &&
                                            ((req_addr[13:2] == 12'hfff) ||
                                             (req_addr[13:2] == 12'hffe));
                            state <= S_VGA_RESP;
                        end else if (dev_timer) begin
                            resp_rdata <= timer_value;
                            resp_valid <= 1'b1;
                        end else if (dev_uart) begin
                            if (req_we && !uart_busy) begin
                                uart_data <= req_wdata[7:0];
                                uart_send <= 1'b1;
                            end
                            resp_rdata <= {31'h0, uart_busy};
                            resp_valid <= 1'b1;
                        end else if (dev_nand) begin
                            nand_req_valid <= 1'b1;
                            nand_req_we <= req_we;
                            nand_req_addr <= req_addr[7:0];
                            nand_req_wstrb <= req_wstrb;
                            nand_req_wdata <= req_wdata;
                            state <= S_NAND_WAIT;
                        end else if (dev_led) begin
                            if (req_we && req_addr[7:0] == 8'h00)
                                led_value <= req_wdata[7:0];
                            if (req_we && req_addr[7:0] == 8'h04)
                                diag_value <= req_wdata;
                            resp_rdata <= (req_addr[7:0] == 8'h04) ?
                                          diag_value : {24'h0, led_value};
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
                        resp_valid <= 1'b1;
                        state <= S_IDLE;
                    end
                end

                S_VGA_RESP: begin
                    if (vga_wait_req) begin
                        state <= S_VGA_WAIT;
                    end else begin
                        resp_rdata <= {24'h0, vga_rdata};
                        resp_valid <= 1'b1;
                        state <= S_IDLE;
                    end
                end

                S_VGA_WAIT: begin
                    if (!vga_busy) begin
                        vga_wait_req <= 1'b0;
                        resp_rdata <= {24'h0, vga_rdata};
                        resp_valid <= 1'b1;
                        state <= S_IDLE;
                    end
                end
            endcase
        end
    end
endmodule

`timescale 1ns / 1ps
`default_nettype none

module ddr3_mig_bridge #(
) (
    input  wire                         sys_clk_i,
    input  wire                         sys_rst,
    output wire                         ui_clk,
    output wire                         ui_rst,
    output wire                         init_calib_complete,

    output wire [12:0]                  ddr3_addr,
    output wire [2:0]                   ddr3_ba,
    output wire                         ddr3_cas_n,
    output wire [0:0]                   ddr3_ck_n,
    output wire [0:0]                   ddr3_ck_p,
    output wire [0:0]                   ddr3_cke,
    output wire                         ddr3_ras_n,
    output wire                         ddr3_reset_n,
    output wire                         ddr3_we_n,
    inout  wire [15:0]                  ddr3_dq,
    inout  wire [1:0]                   ddr3_dqs_n,
    inout  wire [1:0]                   ddr3_dqs_p,
    output wire [1:0]                   ddr3_dm,
    output wire [0:0]                   ddr3_odt,

    input  wire                         cpu_req_valid,
    output wire                         cpu_req_ready,
    input  wire                         cpu_req_we,
    input  wire                         cpu_req_line,
    input  wire [3:0]                   cpu_req_wstrb,
    input  wire [31:0]                  cpu_req_addr,
    input  wire [127:0]                 cpu_req_wdata,
    output reg                          cpu_resp_valid,
    input  wire                         cpu_resp_ready,
    output reg  [127:0]                 cpu_resp_rdata
);
    localparam [1:0] S_IDLE      = 2'd0;
    localparam [1:0] S_WRITE     = 2'd1;
    localparam [1:0] S_READ_CMD  = 2'd2;
    localparam [1:0] S_READ_WAIT = 2'd3;

    localparam [2:0] CMD_WRITE = 3'b000;
    localparam [2:0] CMD_READ  = 3'b001;

    wire ui_clk_sync_rst;
    wire clk_ref_200;
    wire clk_ref_locked;
    wire [11:0] device_temp;

    reg [1:0] state;
    reg       cmd_accepted;
    reg       wdf_accepted;

    reg  [26:0]  app_addr;
    reg  [2:0]   app_cmd;
    wire         app_en;
    wire         app_rdy;
    reg  [127:0] app_wdf_data;
    wire         app_wdf_wren;
    wire         app_wdf_end;
    reg  [15:0]  app_wdf_mask;
    wire         app_wdf_rdy;
    wire [127:0] app_rd_data;
    wire         app_rd_data_end;
    wire         app_rd_data_valid;

    wire req_fire = cpu_req_valid && cpu_req_ready;
    wire cmd_fire = app_en && app_rdy;
    wire wdf_fire = app_wdf_wren && app_wdf_rdy;

    assign ui_rst = ui_clk_sync_rst;
    assign cpu_req_ready = (state == S_IDLE) &&
                           init_calib_complete &&
                           (!cpu_resp_valid || cpu_resp_ready);
    assign app_en = (state == S_READ_CMD) ||
                    ((state == S_WRITE) && !cmd_accepted);
    assign app_wdf_wren = (state == S_WRITE) && !wdf_accepted;
    assign app_wdf_end = app_wdf_wren;

    clk_ref_200_gen u_clk_ref_200_gen (
        .clk_in(sys_clk_i),
        .rst(sys_rst),
        .clk_out(clk_ref_200),
        .locked(clk_ref_locked)
    );

    mig_7series_0 u_mig_7series_0 (
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
        .init_calib_complete(init_calib_complete),
        .ddr3_dm(ddr3_dm),
        .ddr3_odt(ddr3_odt),
        .app_addr(app_addr),
        .app_cmd(app_cmd),
        .app_en(app_en),
        .app_wdf_data(app_wdf_data),
        .app_wdf_end(app_wdf_end),
        .app_wdf_wren(app_wdf_wren),
        .app_rd_data(app_rd_data),
        .app_rd_data_end(app_rd_data_end),
        .app_rd_data_valid(app_rd_data_valid),
        .app_rdy(app_rdy),
        .app_wdf_rdy(app_wdf_rdy),
        .app_sr_req(1'b0),
        .app_ref_req(1'b0),
        .app_zq_req(1'b0),
        .app_sr_active(),
        .app_ref_ack(),
        .app_zq_ack(),
        .ui_clk(ui_clk),
        .ui_clk_sync_rst(ui_clk_sync_rst),
        .app_wdf_mask(app_wdf_mask),
        .sys_clk_i(sys_clk_i),
        .clk_ref_i(clk_ref_200),
        .device_temp(device_temp),
        .sys_rst(sys_rst | ~clk_ref_locked)
    );

    always @(posedge ui_clk) begin
        if (ui_clk_sync_rst) begin
            state <= S_IDLE;
            cmd_accepted <= 1'b0;
            wdf_accepted <= 1'b0;
            cpu_resp_valid <= 1'b0;
            cpu_resp_rdata <= 128'h0;
            app_addr <= 27'd0;
            app_cmd <= CMD_WRITE;
            app_wdf_data <= 128'h0;
            app_wdf_mask <= 16'hffff;
        end else begin
            if (cpu_resp_valid && cpu_resp_ready) begin
                cpu_resp_valid <= 1'b0;
            end

            case (state)
                S_IDLE: begin
                    cmd_accepted <= 1'b0;
                    wdf_accepted <= 1'b0;
                    if (req_fire) begin
                        app_addr <= {1'b0, cpu_req_addr[26:4], 3'b000};
                        app_cmd <= cpu_req_we ? CMD_WRITE : CMD_READ;
                        if (cpu_req_we && cpu_req_line) begin
                            app_wdf_data <= cpu_req_wdata;
                            app_wdf_mask <= 16'h0000;
                        end else begin
                            app_wdf_data <= {4{cpu_req_wdata[31:0]}};
                            case (cpu_req_addr[3:2])
                                2'd0: app_wdf_mask <= {12'hfff, ~cpu_req_wstrb};
                                2'd1: app_wdf_mask <= {8'hff, ~cpu_req_wstrb, 4'hf};
                                2'd2: app_wdf_mask <= {4'hf, ~cpu_req_wstrb, 8'hff};
                                default: app_wdf_mask <= {~cpu_req_wstrb, 12'hfff};
                            endcase
                        end
                        state <= cpu_req_we ? S_WRITE : S_READ_CMD;
                    end
                end

                S_WRITE: begin
                    if (cmd_fire) begin
                        cmd_accepted <= 1'b1;
                    end
                    if (wdf_fire) begin
                        wdf_accepted <= 1'b1;
                    end

                    if ((cmd_accepted || cmd_fire) &&
                        (wdf_accepted || wdf_fire)) begin
                        cpu_resp_valid <= 1'b1;
                        cpu_resp_rdata <= 128'h0;
                        state <= S_IDLE;
                    end
                end

                S_READ_CMD: begin
                    if (cmd_fire) begin
                        state <= S_READ_WAIT;
                    end
                end

                S_READ_WAIT: begin
                    if (app_rd_data_valid) begin
                        cpu_resp_rdata <= app_rd_data;
                        cpu_resp_valid <= 1'b1;
                        state <= S_IDLE;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule

`default_nettype wire

`timescale 1ns / 1ps
`default_nettype none

module ddr3_mig_bridge #(
) (
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire                         cpu_req_valid,
    output wire                         cpu_req_ready,
    input  wire                         cpu_req_we,
    input  wire [3:0]                   cpu_req_wstrb,
    input  wire [31:0]                  cpu_req_addr,
    input  wire [31:0]                  cpu_req_wdata,
    output reg                          cpu_resp_valid,
    input  wire                         cpu_resp_ready,
    output reg  [31:0]                  cpu_resp_rdata,

    input  wire                         init_calib_complete,
    output reg  [26:0]    app_addr,
    output reg  [2:0]                   app_cmd,
    output reg                          app_en,
    input  wire                         app_rdy,
    output reg  [127:0]                 app_wdf_data,
    output reg                          app_wdf_wren,
    output wire                         app_wdf_end,
    output reg  [15:0]                  app_wdf_mask,
    input  wire                         app_wdf_rdy,
    input  wire [127:0]                 app_rd_data,
    input  wire                         app_rd_data_valid
);
    localparam [1:0] S_IDLE      = 2'd0;
    localparam [1:0] S_WRITE     = 2'd1;
    localparam [1:0] S_READ_CMD  = 2'd2;
    localparam [1:0] S_READ_WAIT = 2'd3;

    localparam [2:0] CMD_WRITE = 3'b000;
    localparam [2:0] CMD_READ  = 3'b001;

    reg [1:0]  state;
    reg [31:0] req_addr_q;
    reg [31:0] req_wdata_q;
    reg [3:0]  req_wstrb_q;
    reg        cmd_accepted;
    reg        wdf_accepted;

    wire [1:0] word_sel = req_addr_q[3:2];
    wire [26:0] aligned_app_addr =
        {req_addr_q[26:4], 4'b0000};
    wire [15:0] word_mask =
        ~({12'h000, req_wstrb_q} << {word_sel, 2'b00});
    wire req_fire = cpu_req_valid && cpu_req_ready;
    wire cmd_fire = (!cmd_accepted) && app_rdy;
    wire wdf_fire = (!wdf_accepted) && app_wdf_rdy;

    assign cpu_req_ready = (state == S_IDLE) &&
                           init_calib_complete &&
                           (!cpu_resp_valid || cpu_resp_ready);
    assign app_wdf_end = app_wdf_wren;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            req_addr_q <= 32'h0;
            req_wdata_q <= 32'h0;
            req_wstrb_q <= 4'h0;
            cmd_accepted <= 1'b0;
            wdf_accepted <= 1'b0;
            cpu_resp_valid <= 1'b0;
            cpu_resp_rdata <= 32'h0;
            app_addr <= 27'd0;
            app_cmd <= CMD_WRITE;
            app_en <= 1'b0;
            app_wdf_data <= 128'h0;
            app_wdf_wren <= 1'b0;
            app_wdf_mask <= 16'hffff;
        end else begin
            app_en <= 1'b0;
            app_wdf_wren <= 1'b0;

            if (cpu_resp_valid && cpu_resp_ready) begin
                cpu_resp_valid <= 1'b0;
            end

            case (state)
                S_IDLE: begin
                    cmd_accepted <= 1'b0;
                    wdf_accepted <= 1'b0;
                    if (req_fire) begin
                        req_addr_q <= cpu_req_addr;
                        req_wdata_q <= cpu_req_wdata;
                        req_wstrb_q <= cpu_req_wstrb;
                        state <= cpu_req_we ? S_WRITE : S_READ_CMD;
                    end
                end

                S_WRITE: begin
                    app_addr <= aligned_app_addr;
                    app_cmd <= CMD_WRITE;
                    app_wdf_data <= {4{req_wdata_q}};
                    app_wdf_mask <= word_mask;

                    if (!cmd_accepted) begin
                        app_en <= 1'b1;
                    end
                    if (!wdf_accepted) begin
                        app_wdf_wren <= 1'b1;
                    end

                    if (cmd_fire) begin
                        cmd_accepted <= 1'b1;
                    end
                    if (wdf_fire) begin
                        wdf_accepted <= 1'b1;
                    end

                    if ((cmd_accepted || cmd_fire) &&
                        (wdf_accepted || wdf_fire)) begin
                        cpu_resp_valid <= 1'b1;
                        cpu_resp_rdata <= 32'h0;
                        state <= S_IDLE;
                    end
                end

                S_READ_CMD: begin
                    app_addr <= aligned_app_addr;
                    app_cmd <= CMD_READ;
                    app_en <= 1'b1;
                    if (app_rdy) begin
                        state <= S_READ_WAIT;
                    end
                end

                S_READ_WAIT: begin
                    if (app_rd_data_valid) begin
                        case (word_sel)
                            2'd0: cpu_resp_rdata <= app_rd_data[31:0];
                            2'd1: cpu_resp_rdata <= app_rd_data[63:32];
                            2'd2: cpu_resp_rdata <= app_rd_data[95:64];
                            default: cpu_resp_rdata <= app_rd_data[127:96];
                        endcase
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

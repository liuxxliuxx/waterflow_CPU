`timescale 1ns / 1ps

module ddr_cdc_bridge (
    input  wire        src_clk,
    input  wire        src_rst_n,
    input  wire        src_req_valid,
    output wire        src_req_ready,
    input  wire        src_req_we,
    input  wire        src_req_line,
    input  wire [3:0]  src_req_wstrb,
    input  wire [31:0] src_req_addr,
    input  wire [127:0] src_req_wdata,
    output wire        src_resp_valid,
    input  wire        src_resp_ready,
    output wire [127:0] src_resp_rdata,

    input  wire        dst_clk,
    input  wire        dst_rst,
    output wire        dst_req_valid,
    input  wire        dst_req_ready,
    output wire        dst_req_we,
    output wire        dst_req_line,
    output wire [3:0]  dst_req_wstrb,
    output wire [31:0] dst_req_addr,
    output wire [127:0] dst_req_wdata,
    input  wire        dst_resp_valid,
    input  wire [127:0] dst_resp_rdata
);
    localparam [1:0] DST_IDLE = 2'd0;
    localparam [1:0] DST_REQ  = 2'd1;
    localparam [1:0] DST_RESP = 2'd2;

    reg        src_busy;
    reg        src_req_toggle;
    (* ASYNC_REG = "TRUE" *) reg src_resp_sync1;
    (* ASYNC_REG = "TRUE" *) reg src_resp_sync2;
    reg        src_resp_seen;
    reg        src_req_we_q;
    reg        src_req_line_q;
    reg [3:0]  src_req_wstrb_q;
    reg [31:0] src_req_addr_q;
    reg [127:0] src_req_wdata_q;

    (* ASYNC_REG = "TRUE" *) reg dst_req_sync1;
    (* ASYNC_REG = "TRUE" *) reg dst_req_sync2;
    reg        dst_req_seen;
    reg        dst_resp_toggle;
    reg [127:0] dst_resp_rdata_q;
    reg [1:0]  dst_state;

    assign src_req_ready = !src_busy;
    assign src_resp_valid = src_busy && (src_resp_sync2 != src_resp_seen);
    assign src_resp_rdata = dst_resp_rdata_q;

    assign dst_req_valid = (dst_state == DST_REQ);
    assign dst_req_we = src_req_we_q;
    assign dst_req_line = src_req_line_q;
    assign dst_req_wstrb = src_req_wstrb_q;
    assign dst_req_addr = src_req_addr_q;
    assign dst_req_wdata = src_req_wdata_q;

    always @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            src_busy <= 1'b0;
            src_req_toggle <= 1'b0;
            src_resp_sync1 <= 1'b0;
            src_resp_sync2 <= 1'b0;
            src_resp_seen <= 1'b0;
            src_req_we_q <= 1'b0;
            src_req_line_q <= 1'b0;
            src_req_wstrb_q <= 4'b0;
            src_req_addr_q <= 32'b0;
            src_req_wdata_q <= 128'b0;
        end else begin
            src_resp_sync1 <= dst_resp_toggle;
            src_resp_sync2 <= src_resp_sync1;

            if (src_req_valid && src_req_ready) begin
                src_busy <= 1'b1;
                src_req_we_q <= src_req_we;
                src_req_line_q <= src_req_line;
                src_req_wstrb_q <= src_req_wstrb;
                src_req_addr_q <= src_req_addr;
                src_req_wdata_q <= src_req_wdata;
                src_req_toggle <= ~src_req_toggle;
            end

            if (src_resp_valid && src_resp_ready) begin
                src_resp_seen <= src_resp_sync2;
                src_busy <= 1'b0;
            end
        end
    end

    always @(posedge dst_clk or posedge dst_rst) begin
        if (dst_rst) begin
            dst_req_sync1 <= 1'b0;
            dst_req_sync2 <= 1'b0;
            dst_req_seen <= 1'b0;
            dst_resp_toggle <= 1'b0;
            dst_resp_rdata_q <= 128'b0;
            dst_state <= DST_IDLE;
        end else begin
            dst_req_sync1 <= src_req_toggle;
            dst_req_sync2 <= dst_req_sync1;

            case (dst_state)
                DST_IDLE: begin
                    if (dst_req_sync2 != dst_req_seen) begin
                        dst_req_seen <= dst_req_sync2;
                        dst_state <= DST_REQ;
                    end
                end

                DST_REQ: begin
                    if (dst_req_ready) begin
                        dst_state <= DST_RESP;
                    end
                end

                DST_RESP: begin
                    if (dst_resp_valid) begin
                        dst_resp_rdata_q <= dst_resp_rdata;
                        dst_resp_toggle <= ~dst_resp_toggle;
                        dst_state <= DST_IDLE;
                    end
                end

                default: dst_state <= DST_IDLE;
            endcase
        end
    end
endmodule

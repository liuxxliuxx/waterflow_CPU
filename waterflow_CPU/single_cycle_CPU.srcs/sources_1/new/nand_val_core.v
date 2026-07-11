`timescale 1ns / 1ps

// NAND signal-level engine.  Higher layers issue one byte-write, byte-read,
// or ready-wait operation; this block exclusively owns the physical pins.
module nand_val_core #(
    parameter [31:0] MIN_READY_WAIT_CYCLES = 32'd8
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire        req_valid,
    output wire        req_ready,
    input  wire [1:0]  req_op,
    input  wire [7:0]  req_wdata,
    input  wire        req_cle,
    input  wire        req_ale,
    input  wire [31:0] req_timeout,
    output reg         resp_valid,
    output reg  [7:0]  resp_rdata,
    output reg         resp_error,
    input  wire [7:0]  nand_d_i,
    output reg  [7:0]  nand_d_o,
    output reg         nand_d_oe,
    output reg         nand_cle,
    output reg         nand_ale,
    output wire        nand_ce_n,
    output reg         nand_re_n,
    output reg         nand_we_n,
    output wire        nand_wp_n,
    input  wire        nand_rdy
);
    localparam [1:0] OP_WRITE = 2'd0;
    localparam [1:0] OP_READ  = 2'd1;
    localparam [1:0] OP_WAIT  = 2'd2;

    localparam [3:0] S_IDLE       = 4'd0;
    localparam [3:0] S_WR_LOW     = 4'd1;
    localparam [3:0] S_WR_HOLD    = 4'd2;
    localparam [3:0] S_WR_HIGH    = 4'd3;
    localparam [3:0] S_WR_RECOVER = 4'd4;
    localparam [3:0] S_RD_LOW     = 4'd5;
    localparam [3:0] S_RD_WAIT1   = 4'd6;
    localparam [3:0] S_RD_WAIT2   = 4'd7;
    localparam [3:0] S_RD_SAMPLE  = 4'd8;
    localparam [3:0] S_READY_WAIT = 4'd9;

    reg [3:0] state;
    reg [31:0] wait_count;
    reg [31:0] timeout_count;
    reg [31:0] timeout_limit;

    assign req_ready = (state == S_IDLE) && !resp_valid;
    assign nand_ce_n = !enable;
    assign nand_wp_n = 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            resp_valid <= 1'b0;
            resp_rdata <= 8'd0;
            resp_error <= 1'b0;
            nand_d_o <= 8'd0;
            nand_d_oe <= 1'b0;
            nand_cle <= 1'b0;
            nand_ale <= 1'b0;
            nand_re_n <= 1'b1;
            nand_we_n <= 1'b1;
            wait_count <= 32'd0;
            timeout_count <= 32'd0;
            timeout_limit <= 32'd0;
        end else begin
            if (resp_valid)
                resp_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    nand_d_oe <= 1'b0;
                    nand_cle <= 1'b0;
                    nand_ale <= 1'b0;
                    nand_re_n <= 1'b1;
                    nand_we_n <= 1'b1;
                    if (req_valid && req_ready) begin
                        resp_error <= 1'b0;
                        case (req_op)
                            OP_WRITE: begin
                                nand_d_o <= req_wdata;
                                nand_d_oe <= 1'b1;
                                nand_cle <= req_cle;
                                nand_ale <= req_ale;
                                state <= S_WR_LOW;
                            end
                            OP_READ: begin
                                state <= S_RD_LOW;
                            end
                            default: begin
                                wait_count <= 32'd0;
                                timeout_count <= 32'd0;
                                timeout_limit <= req_timeout;
                                state <= S_READY_WAIT;
                            end
                        endcase
                    end
                end
                S_WR_LOW: begin
                    nand_we_n <= 1'b0;
                    state <= S_WR_HOLD;
                end
                S_WR_HOLD: begin
                    state <= S_WR_HIGH;
                end
                S_WR_HIGH: begin
                    nand_we_n <= 1'b1;
                    state <= S_WR_RECOVER;
                end
                S_WR_RECOVER: begin
                    nand_d_oe <= 1'b0;
                    nand_cle <= 1'b0;
                    nand_ale <= 1'b0;
                    resp_valid <= 1'b1;
                    state <= S_IDLE;
                end
                S_RD_LOW: begin
                    nand_re_n <= 1'b0;
                    state <= S_RD_WAIT1;
                end
                S_RD_WAIT1: begin
                    state <= S_RD_WAIT2;
                end
                S_RD_WAIT2: begin
                    state <= S_RD_SAMPLE;
                end
                S_RD_SAMPLE: begin
                    resp_rdata <= nand_d_i;
                    nand_re_n <= 1'b1;
                    resp_valid <= 1'b1;
                    state <= S_IDLE;
                end
                S_READY_WAIT: begin
                    if (wait_count < MIN_READY_WAIT_CYCLES) begin
                        wait_count <= wait_count + 32'd1;
                    end else if (nand_rdy) begin
                        resp_valid <= 1'b1;
                        state <= S_IDLE;
                    end else if (timeout_count >= timeout_limit) begin
                        resp_error <= 1'b1;
                        resp_valid <= 1'b1;
                        state <= S_IDLE;
                    end else begin
                        timeout_count <= timeout_count + 32'd1;
                    end
                end
                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule

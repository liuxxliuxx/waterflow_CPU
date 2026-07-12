`timescale 1ns / 1ps

// Converts NAND page protocol into a back-pressured stream of 32-bit words.
module nand_read_engine #(
    parameter [31:0] MIN_READY_WAIT_CYCLES = 32'd8,
    parameter [31:0] READ_TIMEOUT_CYCLES = 32'd25_000_000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        req_valid,
    output wire        req_ready,
    input  wire [24:0] req_word_index,
    input  wire [31:0] req_word_count,
    output reg         data_valid,
    input  wire        data_ready,
    output reg  [31:0] data,
    output wire        done,
    output reg         error,
    input  wire [7:0]  nand_d_i,
    output wire [7:0]  nand_d_o,
    output wire        nand_d_oe,
    output wire        nand_cle,
    output wire        nand_ale,
    output wire        nand_ce_n,
    output wire        nand_re_n,
    output wire        nand_we_n,
    output wire        nand_wp_n,
    input  wire        nand_rdy
);
    localparam [4:0] S_IDLE       = 5'd0;
    localparam [4:0] S_RESET      = 5'd1;
    localparam [4:0] S_RESET_WAIT = 5'd2;
    localparam [4:0] S_CMD00      = 5'd3;
    localparam [4:0] S_ADDR       = 5'd4;
    localparam [4:0] S_ADDR_NEXT  = 5'd5;
    localparam [4:0] S_CMD30      = 5'd6;
    localparam [4:0] S_PAGE_WAIT  = 5'd7;
    localparam [4:0] S_READ       = 5'd8;
    localparam [4:0] S_STORE      = 5'd9;
    localparam [4:0] S_OUTPUT     = 5'd10;
    localparam [4:0] S_PHY_WAIT   = 5'd11;
    localparam [4:0] S_DONE       = 5'd12;
    localparam [4:0] S_ERROR      = 5'd13;

    localparam [1:0] PHY_WRITE = 2'd0;
    localparam [1:0] PHY_READ  = 2'd1;
    localparam [1:0] PHY_WAIT  = 2'd2;

    reg [4:0] state;
    reg [4:0] phy_return;
    reg phy_req_valid;
    reg [1:0] phy_req_op;
    reg [7:0] phy_req_wdata;
    reg phy_req_cle;
    reg phy_req_ale;
    reg [31:0] phy_req_timeout;
    wire phy_req_ready;
    wire phy_resp_valid;
    wire phy_resp_error;
    wire [7:0] phy_resp_rdata;
    reg [24:0] word_index;
    reg [31:0] words_remaining;
    reg [2:0] addr_index;
    reg [1:0] byte_index;
    reg [31:0] word_buffer;
    reg reset_done;

    assign req_ready = (state == S_IDLE);
    assign done = (state == S_DONE);

    function [7:0] address_byte;
        input [2:0] index;
        input [24:0] word;
        begin
            case (index)
                3'd0: address_byte = {word[5:0], 2'b00};
                3'd1: address_byte = {5'b00000, word[8:6]};
                3'd2: address_byte = word[16:9];
                3'd3: address_byte = word[24:17];
                default: address_byte = 8'h00;
            endcase
        end
    endfunction

    nand_val_core #(
        .MIN_READY_WAIT_CYCLES(MIN_READY_WAIT_CYCLES)
    ) u_phy (
        .clk(clk),
        .rst_n(rst_n),
        .enable((state != S_IDLE) &&
                (state != S_DONE) &&
                (state != S_ERROR)),
        .req_valid(phy_req_valid),
        .req_ready(phy_req_ready),
        .req_op(phy_req_op),
        .req_wdata(phy_req_wdata),
        .req_cle(phy_req_cle),
        .req_ale(phy_req_ale),
        .req_timeout(phy_req_timeout),
        .resp_valid(phy_resp_valid),
        .resp_rdata(phy_resp_rdata),
        .resp_error(phy_resp_error),
        .nand_d_i(nand_d_i),
        .nand_d_o(nand_d_o),
        .nand_d_oe(nand_d_oe),
        .nand_cle(nand_cle),
        .nand_ale(nand_ale),
        .nand_ce_n(nand_ce_n),
        .nand_re_n(nand_re_n),
        .nand_we_n(nand_we_n),
        .nand_wp_n(nand_wp_n),
        .nand_rdy(nand_rdy)
    );

    task issue;
        input [1:0] op;
        input [7:0] value;
        input cle;
        input ale;
        input [31:0] timeout;
        input [4:0] next_state;
        begin
            phy_req_valid <= 1'b1;
            phy_req_op <= op;
            phy_req_wdata <= value;
            phy_req_cle <= cle;
            phy_req_ale <= ale;
            phy_req_timeout <= timeout;
            phy_return <= next_state;
            state <= S_PHY_WAIT;
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            phy_return <= S_IDLE;
            phy_req_valid <= 1'b0;
            phy_req_op <= PHY_WRITE;
            phy_req_wdata <= 8'd0;
            phy_req_cle <= 1'b0;
            phy_req_ale <= 1'b0;
            phy_req_timeout <= 32'd0;
            data_valid <= 1'b0;
            data <= 32'd0;
            error <= 1'b0;
            word_index <= 25'd0;
            words_remaining <= 32'd0;
            addr_index <= 3'd0;
            byte_index <= 2'd0;
            word_buffer <= 32'd0;
            reset_done <= 1'b0;
        end else begin
            phy_req_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    data_valid <= 1'b0;
                    error <= 1'b0;
                    if (req_valid) begin
                        word_index <= req_word_index;
                        words_remaining <= req_word_count;
                        if (req_word_count == 32'd0)
                            state <= S_DONE;
                        else if (!reset_done)
                            state <= S_RESET;
                        else
                            state <= S_CMD00;
                    end
                end
                S_RESET: begin
                    issue(PHY_WRITE, 8'hff, 1'b1, 1'b0,
                          32'd0, S_RESET_WAIT);
                end
                S_RESET_WAIT: begin
                    issue(PHY_WAIT, 8'd0, 1'b0, 1'b0,
                          READ_TIMEOUT_CYCLES, S_CMD00);
                end
                S_CMD00: begin
                    addr_index <= 3'd0;
                    byte_index <= 2'd0;
                    word_buffer <= 32'd0;
                    issue(PHY_WRITE, 8'h00, 1'b1, 1'b0,
                          32'd0, S_ADDR);
                end
                S_ADDR: begin
                    issue(PHY_WRITE, address_byte(addr_index, word_index),
                          1'b0, 1'b1, 32'd0, S_ADDR_NEXT);
                end
                S_ADDR_NEXT: begin
                    if (addr_index == 3'd4) begin
                        state <= S_CMD30;
                    end else begin
                        addr_index <= addr_index + 3'd1;
                        state <= S_ADDR;
                    end
                end
                S_CMD30: begin
                    issue(PHY_WRITE, 8'h30, 1'b1, 1'b0,
                          32'd0, S_PAGE_WAIT);
                end
                S_PAGE_WAIT: begin
                    issue(PHY_WAIT, 8'd0, 1'b0, 1'b0,
                          READ_TIMEOUT_CYCLES, S_READ);
                end
                S_READ: begin
                    issue(PHY_READ, 8'd0, 1'b0, 1'b0,
                          32'd0, S_STORE);
                end
                S_STORE: begin
                    case (byte_index)
                        2'd0: word_buffer[7:0] <= phy_resp_rdata;
                        2'd1: word_buffer[15:8] <= phy_resp_rdata;
                        2'd2: word_buffer[23:16] <= phy_resp_rdata;
                        default: word_buffer[31:24] <= phy_resp_rdata;
                    endcase

                    if (byte_index == 2'd3) begin
                        data <= {phy_resp_rdata, word_buffer[23:0]};
                        data_valid <= 1'b1;
                        state <= S_OUTPUT;
                    end else begin
                        byte_index <= byte_index + 2'd1;
                        state <= S_READ;
                    end
                end
                S_OUTPUT: begin
                    if (data_valid && data_ready) begin
                        data_valid <= 1'b0;
                        if (words_remaining == 32'd1) begin
                            words_remaining <= 32'd0;
                            state <= S_DONE;
                        end else begin
                            words_remaining <= words_remaining - 32'd1;
                            word_index <= word_index + 25'd1;
                            if (word_index[8:0] == 9'h1ff) begin
                                state <= S_CMD00;
                            end else begin
                                byte_index <= 2'd0;
                                word_buffer <= 32'd0;
                                state <= S_READ;
                            end
                        end
                    end
                end
                S_PHY_WAIT: begin
                    if (phy_resp_valid) begin
                        if (phy_resp_error) begin
                            error <= 1'b1;
                            state <= S_ERROR;
                        end else begin
                            state <= phy_return;
                            if (phy_return == S_CMD00)
                                reset_done <= 1'b1;
                        end
                    end
                end
                S_DONE: begin
                    if (!req_valid)
                        state <= S_IDLE;
                end
                S_ERROR: begin
                    if (!req_valid)
                        state <= S_IDLE;
                end
                default: state <= S_ERROR;
            endcase
        end
    end
endmodule

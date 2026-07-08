`timescale 1ns/1ps

module nand_val_core #(
    parameter [24:0] INITIAL_WORD_INDEX = 25'd0,
    parameter        POWERUP_WAIT_CYCLES = 1024,
    parameter        MIN_READY_WAIT_CYCLES = 8,
    parameter        RESET_TIMEOUT_CYCLES = 25000000,
    parameter        READ_TIMEOUT_CYCLES = 25000000
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        step_pulse,
    input  wire        set_index_pulse,
    input  wire [24:0] set_word_index,
    inout  wire [7:0]  nand_d,
    output reg         nand_cle,
    output reg         nand_ale,
    output reg         nand_ce_n,
    output reg         nand_re_n,
    output reg         nand_we_n,
    output reg         nand_wp_n,
    input  wire        nand_rdy,
    output reg  [31:0] current_word,
    output reg  [24:0] word_index,
    output reg         word_valid,
    output reg         busy,
    output reg         error
);
    localparam S_POWERUP          = 8'd0;
    localparam S_RESET_CMD        = 8'd1;
    localparam S_RESET_WAIT       = 8'd2;
    localparam S_READ_CMD00       = 8'd3;
    localparam S_READ_ADDR_NEXT   = 8'd4;
    localparam S_READ_ADDR_ADV    = 8'd5;
    localparam S_READ_CMD30       = 8'd6;
    localparam S_READ_WAIT        = 8'd7;
    localparam S_READ_BYTE_NEXT   = 8'd8;
    localparam S_READ_BYTE_STORE  = 8'd9;
    localparam S_SHOW             = 8'd10;
    localparam S_ERROR            = 8'd11;
    localparam S_WAIT_RDY         = 8'd12;
    localparam S_WR_SETUP         = 8'd13;
    localparam S_WR_LOW           = 8'd14;
    localparam S_WR_LOW_HOLD      = 8'd15;
    localparam S_WR_HIGH          = 8'd16;
    localparam S_WR_RECOVER       = 8'd17;
    localparam S_RD_SETUP         = 8'd18;
    localparam S_RD_LOW           = 8'd19;
    localparam S_RD_WAIT1         = 8'd20;
    localparam S_RD_WAIT2         = 8'd21;
    localparam S_RD_SAMPLE        = 8'd22;

    reg [7:0]  state;
    reg [7:0]  wr_return;
    reg [7:0]  wait_return;
    reg [7:0]  rd_return;
    reg [7:0]  wr_data;
    reg        wr_cle;
    reg        wr_ale;
    reg [7:0]  dq_out;
    reg        dq_oe;
    reg [2:0]  addr_index;
    reg [1:0]  byte_index;
    reg [7:0]  rd_sample;
    reg [31:0] read_word;
    reg [31:0] wait_count;
    reg [31:0] timeout_ctr;
    reg [31:0] timeout_limit;

    assign nand_d = dq_oe ? dq_out : 8'hzz;

    function [7:0] read_addr_byte;
        input [2:0]  index;
        input [24:0] word;
        begin
            case (index)
                3'd0: read_addr_byte = {word[5:0], 2'b00};
                3'd1: read_addr_byte = {5'b00000, word[8:6]};
                3'd2: read_addr_byte = word[16:9];
                3'd3: read_addr_byte = word[24:17];
                default: read_addr_byte = 8'h00;
            endcase
        end
    endfunction

    task queue_write_byte;
        input [7:0] data;
        input       cle;
        input       ale;
        input [7:0] next_state;
        begin
            wr_data <= data;
            wr_cle <= cle;
            wr_ale <= ale;
            wr_return <= next_state;
            state <= S_WR_SETUP;
        end
    endtask

    task queue_ready_wait;
        input [31:0] limit;
        input [7:0]  next_state;
        begin
            timeout_ctr <= 32'd0;
            wait_count <= 32'd0;
            timeout_limit <= limit;
            wait_return <= next_state;
            state <= S_WAIT_RDY;
        end
    endtask

    task queue_data_read;
        input [7:0] next_state;
        begin
            rd_return <= next_state;
            state <= S_RD_SETUP;
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            state <= S_POWERUP;
            wr_return <= S_POWERUP;
            wait_return <= S_POWERUP;
            rd_return <= S_POWERUP;
            wr_data <= 8'h00;
            wr_cle <= 1'b0;
            wr_ale <= 1'b0;
            dq_out <= 8'h00;
            dq_oe <= 1'b0;
            addr_index <= 3'd0;
            byte_index <= 2'd0;
            rd_sample <= 8'h00;
            read_word <= 32'h00000000;
            wait_count <= 32'd0;
            timeout_ctr <= 32'd0;
            timeout_limit <= 32'd0;
            current_word <= 32'h00000000;
            word_index <= INITIAL_WORD_INDEX;
            word_valid <= 1'b0;
            busy <= 1'b1;
            error <= 1'b0;
            nand_cle <= 1'b0;
            nand_ale <= 1'b0;
            nand_ce_n <= 1'b1;
            nand_re_n <= 1'b1;
            nand_we_n <= 1'b1;
            nand_wp_n <= 1'b1;
        end else begin
            case (state)
                S_POWERUP: begin
                    busy <= 1'b1;
                    error <= 1'b0;
                    nand_ce_n <= 1'b1;
                    nand_re_n <= 1'b1;
                    nand_we_n <= 1'b1;
                    nand_wp_n <= 1'b1;
                    dq_oe <= 1'b0;
                    if (wait_count >= POWERUP_WAIT_CYCLES) begin
                        wait_count <= 32'd0;
                        state <= S_RESET_CMD;
                    end else begin
                        wait_count <= wait_count + 32'd1;
                    end
                end

                S_RESET_CMD: begin
                    nand_ce_n <= 1'b0;
                    nand_wp_n <= 1'b1;
                    queue_write_byte(8'hff, 1'b1, 1'b0, S_RESET_WAIT);
                end

                S_RESET_WAIT: begin
                    queue_ready_wait(RESET_TIMEOUT_CYCLES, S_READ_CMD00);
                end

                S_READ_CMD00: begin
                    busy <= 1'b1;
                    word_valid <= 1'b0;
                    addr_index <= 3'd0;
                    byte_index <= 2'd0;
                    read_word <= 32'h00000000;
                    nand_ce_n <= 1'b0;
                    nand_wp_n <= 1'b1;
                    queue_write_byte(8'h00, 1'b1, 1'b0, S_READ_ADDR_NEXT);
                end

                S_READ_ADDR_NEXT: begin
                    queue_write_byte(read_addr_byte(addr_index, word_index), 1'b0, 1'b1, S_READ_ADDR_ADV);
                end

                S_READ_ADDR_ADV: begin
                    if (addr_index == 3'd4) begin
                        state <= S_READ_CMD30;
                    end else begin
                        addr_index <= addr_index + 3'd1;
                        state <= S_READ_ADDR_NEXT;
                    end
                end

                S_READ_CMD30: begin
                    queue_write_byte(8'h30, 1'b1, 1'b0, S_READ_WAIT);
                end

                S_READ_WAIT: begin
                    queue_ready_wait(READ_TIMEOUT_CYCLES, S_READ_BYTE_NEXT);
                end

                S_READ_BYTE_NEXT: begin
                    queue_data_read(S_READ_BYTE_STORE);
                end

                S_READ_BYTE_STORE: begin
                    case (byte_index)
                        2'd0: read_word[7:0] <= rd_sample;
                        2'd1: read_word[15:8] <= rd_sample;
                        2'd2: read_word[23:16] <= rd_sample;
                        default: read_word[31:24] <= rd_sample;
                    endcase

                    if (byte_index == 2'd3) begin
                        current_word <= {rd_sample, read_word[23:0]};
                        word_valid <= 1'b1;
                        busy <= 1'b0;
                        nand_ce_n <= 1'b1;
                        state <= S_SHOW;
                    end else begin
                        byte_index <= byte_index + 2'd1;
                        state <= S_READ_BYTE_NEXT;
                    end
                end

                S_SHOW: begin
                    busy <= 1'b0;
                    nand_ce_n <= 1'b1;
                    nand_re_n <= 1'b1;
                    nand_we_n <= 1'b1;
                    nand_cle <= 1'b0;
                    nand_ale <= 1'b0;
                    dq_oe <= 1'b0;
                    if (set_index_pulse) begin
                        busy <= 1'b1;
                        word_valid <= 1'b0;
                        word_index <= set_word_index;
                        state <= S_READ_CMD00;
                    end else if (step_pulse) begin
                        busy <= 1'b1;
                        word_valid <= 1'b0;
                        word_index <= word_index + 25'd1;
                        state <= S_READ_CMD00;
                    end
                end

                S_ERROR: begin
                    error <= 1'b1;
                    busy <= 1'b0;
                    nand_ce_n <= 1'b1;
                    nand_re_n <= 1'b1;
                    nand_we_n <= 1'b1;
                    nand_cle <= 1'b0;
                    nand_ale <= 1'b0;
                    dq_oe <= 1'b0;
                    state <= S_ERROR;
                end

                S_WAIT_RDY: begin
                    if (wait_count < MIN_READY_WAIT_CYCLES) begin
                        wait_count <= wait_count + 32'd1;
                    end else if (nand_rdy) begin
                        state <= wait_return;
                    end else if (timeout_ctr >= timeout_limit) begin
                        state <= S_ERROR;
                    end else begin
                        timeout_ctr <= timeout_ctr + 32'd1;
                    end
                end

                S_WR_SETUP: begin
                    nand_re_n <= 1'b1;
                    nand_we_n <= 1'b1;
                    nand_cle <= wr_cle;
                    nand_ale <= wr_ale;
                    dq_out <= wr_data;
                    dq_oe <= 1'b1;
                    state <= S_WR_LOW;
                end

                S_WR_LOW: begin
                    nand_we_n <= 1'b0;
                    state <= S_WR_LOW_HOLD;
                end

                S_WR_LOW_HOLD: begin
                    state <= S_WR_HIGH;
                end

                S_WR_HIGH: begin
                    nand_we_n <= 1'b1;
                    state <= S_WR_RECOVER;
                end

                S_WR_RECOVER: begin
                    nand_cle <= 1'b0;
                    nand_ale <= 1'b0;
                    dq_oe <= 1'b0;
                    state <= wr_return;
                end

                S_RD_SETUP: begin
                    nand_cle <= 1'b0;
                    nand_ale <= 1'b0;
                    nand_we_n <= 1'b1;
                    nand_re_n <= 1'b1;
                    dq_oe <= 1'b0;
                    state <= S_RD_LOW;
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
                    rd_sample <= nand_d;
                    nand_re_n <= 1'b1;
                    state <= rd_return;
                end

                default: begin
                    state <= S_ERROR;
                end
            endcase
        end
    end
endmodule

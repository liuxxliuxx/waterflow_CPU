`timescale 1ns / 1ps

// Reads a raw, contiguous NAND image and writes it to DDR before the CPU starts.
// The K9F1G08U0C has 2 KiB data pages, so one NAND page contains 512 words.
module nand_boot_loader #(
    parameter [24:0] BOOT_NAND_START_WORD  = 25'd0,
    parameter [31:0] BOOT_WORDS             = 32'd1024,
    parameter [31:0] BOOT_LOAD_ADDR         = 32'h1c00_0000,
    parameter [31:0] DDR_TIMEOUT_CYCLES     = 32'd25_000_000,
    parameter [31:0] MIN_READY_WAIT_CYCLES  = 32'd8,
    parameter [31:0] RESET_TIMEOUT_CYCLES   = 32'd25_000_000,
    parameter [31:0] READ_TIMEOUT_CYCLES    = 32'd25_000_000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ddr_ready,

    output wire        ddr_req_valid,
    input  wire        ddr_req_ready,
    output wire [31:0] ddr_req_addr,
    output wire [31:0] ddr_req_wdata,
    input  wire        ddr_resp_valid,

    input  wire [7:0] nand_d_i,
    output wire [7:0] nand_d_o,
    output wire       nand_d_oe,
    output reg         nand_cle,
    output reg         nand_ale,
    output reg         nand_ce_n,
    output reg         nand_re_n,
    output reg         nand_we_n,
    output reg         nand_wp_n,
    input  wire        nand_rdy,

    output reg         boot_done,
    output reg         boot_error
);
    localparam [4:0] S_WAIT_DDR        = 5'd0;
    localparam [4:0] S_RESET_CMD       = 5'd1;
    localparam [4:0] S_RESET_WAIT      = 5'd2;
    localparam [4:0] S_PAGE_CMD00      = 5'd3;
    localparam [4:0] S_PAGE_ADDR       = 5'd4;
    localparam [4:0] S_PAGE_ADDR_NEXT  = 5'd5;
    localparam [4:0] S_PAGE_CMD30      = 5'd6;
    localparam [4:0] S_PAGE_WAIT       = 5'd7;
    localparam [4:0] S_READ_BYTE       = 5'd8;
    localparam [4:0] S_STORE_BYTE      = 5'd9;
    localparam [4:0] S_DDR_REQ         = 5'd10;
    localparam [4:0] S_DDR_WAIT        = 5'd11;
    localparam [4:0] S_DONE            = 5'd12;
    localparam [4:0] S_ERROR           = 5'd13;
    localparam [4:0] S_WAIT_READY      = 5'd14;
    localparam [4:0] S_WR_SETUP        = 5'd15;
    localparam [4:0] S_WR_LOW          = 5'd16;
    localparam [4:0] S_WR_LOW_HOLD     = 5'd17;
    localparam [4:0] S_WR_HIGH         = 5'd18;
    localparam [4:0] S_WR_RECOVER      = 5'd19;
    localparam [4:0] S_RD_SETUP        = 5'd20;
    localparam [4:0] S_RD_LOW          = 5'd21;
    localparam [4:0] S_RD_WAIT1        = 5'd22;
    localparam [4:0] S_RD_WAIT2        = 5'd23;
    localparam [4:0] S_RD_SAMPLE       = 5'd24;

    reg [4:0] state;
    reg [4:0] write_return;
    reg [4:0] wait_return;
    reg [4:0] read_return;
    reg [7:0] write_data;
    reg       write_cle;
    reg       write_ale;
    reg [7:0] nand_d_out;
    reg       nand_d_oe_reg;
    reg [2:0] addr_index;
    reg [1:0] byte_index;
    reg [7:0] read_sample;
    reg [31:0] assembled_word;
    reg [31:0] pending_word;
    reg [24:0] source_word;
    reg [31:0] words_written;
    reg [9:0] words_in_page;
    reg [31:0] wait_count;
    reg [31:0] timeout_count;
    reg [31:0] timeout_limit;

    assign nand_d_o = nand_d_out;
    assign nand_d_oe = nand_d_oe_reg;
    assign ddr_req_valid = (state == S_DDR_REQ);
    assign ddr_req_addr = BOOT_LOAD_ADDR + {words_written[29:0], 2'b00};
    assign ddr_req_wdata = pending_word;

    function [7:0] nand_address_byte;
        input [2:0] index;
        input [24:0] word_index;
        begin
            case (index)
                3'd0: nand_address_byte = {word_index[5:0], 2'b00};
                3'd1: nand_address_byte = {5'b00000, word_index[8:6]};
                3'd2: nand_address_byte = word_index[16:9];
                3'd3: nand_address_byte = word_index[24:17];
                default: nand_address_byte = 8'h00;
            endcase
        end
    endfunction

    task queue_write_byte;
        input [7:0] value;
        input       cle;
        input       ale;
        input [4:0] next_state;
        begin
            write_data <= value;
            write_cle <= cle;
            write_ale <= ale;
            write_return <= next_state;
            state <= S_WR_SETUP;
        end
    endtask

    task queue_ready_wait;
        input [31:0] limit;
        input [4:0] next_state;
        begin
            wait_count <= 32'd0;
            timeout_count <= 32'd0;
            timeout_limit <= limit;
            wait_return <= next_state;
            state <= S_WAIT_READY;
        end
    endtask

    task queue_read_byte;
        input [4:0] next_state;
        begin
            read_return <= next_state;
            state <= S_RD_SETUP;
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_WAIT_DDR;
            write_return <= S_WAIT_DDR;
            wait_return <= S_WAIT_DDR;
            read_return <= S_WAIT_DDR;
            write_data <= 8'h00;
            write_cle <= 1'b0;
            write_ale <= 1'b0;
            nand_d_out <= 8'h00;
            nand_d_oe_reg <= 1'b0;
            addr_index <= 3'd0;
            byte_index <= 2'd0;
            read_sample <= 8'h00;
            assembled_word <= 32'h0000_0000;
            pending_word <= 32'h0000_0000;
            source_word <= BOOT_NAND_START_WORD;
            words_written <= 32'd0;
            words_in_page <= 10'd0;
            wait_count <= 32'd0;
            timeout_count <= 32'd0;
            timeout_limit <= 32'd0;
            nand_cle <= 1'b0;
            nand_ale <= 1'b0;
            nand_ce_n <= 1'b1;
            nand_re_n <= 1'b1;
            nand_we_n <= 1'b1;
            nand_wp_n <= 1'b1;
            boot_done <= 1'b0;
            boot_error <= 1'b0;
        end else begin
            case (state)
                S_WAIT_DDR: begin
                    nand_ce_n <= 1'b1;
                    nand_re_n <= 1'b1;
                    nand_we_n <= 1'b1;
                    nand_wp_n <= 1'b1;
                    nand_cle <= 1'b0;
                    nand_ale <= 1'b0;
                    nand_d_oe_reg <= 1'b0;
                    if (ddr_ready) begin
                        timeout_count <= 32'd0;
                        nand_ce_n <= 1'b0;
                        state <= S_RESET_CMD;
                    end else if (timeout_count >= DDR_TIMEOUT_CYCLES) begin
                        state <= S_ERROR;
                    end else begin
                        timeout_count <= timeout_count + 32'd1;
                    end
                end

                S_RESET_CMD: begin
                    nand_ce_n <= 1'b0;
                    queue_write_byte(8'hff, 1'b1, 1'b0, S_RESET_WAIT);
                end

                S_RESET_WAIT: begin
                    queue_ready_wait(RESET_TIMEOUT_CYCLES, S_PAGE_CMD00);
                end

                S_PAGE_CMD00: begin
                    if (words_written == BOOT_WORDS) begin
                        state <= S_DONE;
                    end else begin
                        addr_index <= 3'd0;
                        byte_index <= 2'd0;
                        assembled_word <= 32'h0000_0000;
                        nand_ce_n <= 1'b0;
                        if ((BOOT_WORDS - words_written) <=
                            (32'd512 - {23'd0, source_word[8:0]})) begin
                            words_in_page <= BOOT_WORDS - words_written;
                        end else begin
                            words_in_page <= 32'd512 - {23'd0, source_word[8:0]};
                        end
                        queue_write_byte(8'h00, 1'b1, 1'b0, S_PAGE_ADDR);
                    end
                end

                S_PAGE_ADDR: begin
                    queue_write_byte(nand_address_byte(addr_index, source_word),
                                     1'b0, 1'b1, S_PAGE_ADDR_NEXT);
                end

                S_PAGE_ADDR_NEXT: begin
                    if (addr_index == 3'd4) begin
                        state <= S_PAGE_CMD30;
                    end else begin
                        addr_index <= addr_index + 3'd1;
                        state <= S_PAGE_ADDR;
                    end
                end

                S_PAGE_CMD30: begin
                    queue_write_byte(8'h30, 1'b1, 1'b0, S_PAGE_WAIT);
                end

                S_PAGE_WAIT: begin
                    queue_ready_wait(READ_TIMEOUT_CYCLES, S_READ_BYTE);
                end

                S_READ_BYTE: begin
                    queue_read_byte(S_STORE_BYTE);
                end

                S_STORE_BYTE: begin
                    case (byte_index)
                        2'd0: assembled_word[7:0] <= read_sample;
                        2'd1: assembled_word[15:8] <= read_sample;
                        2'd2: assembled_word[23:16] <= read_sample;
                        default: assembled_word[31:24] <= read_sample;
                    endcase

                    if (byte_index == 2'd3) begin
                        pending_word <= {read_sample, assembled_word[23:0]};
                        state <= S_DDR_REQ;
                    end else begin
                        byte_index <= byte_index + 2'd1;
                        state <= S_READ_BYTE;
                    end
                end

                S_DDR_REQ: begin
                    if (ddr_req_ready) begin
                        state <= S_DDR_WAIT;
                    end
                end

                S_DDR_WAIT: begin
                    if (ddr_resp_valid) begin
                        words_written <= words_written + 32'd1;
                        source_word <= source_word + 25'd1;
                        byte_index <= 2'd0;
                        assembled_word <= 32'h0000_0000;
                        if ((words_written + 32'd1) == BOOT_WORDS) begin
                            state <= S_DONE;
                        end else if (words_in_page == 10'd1) begin
                            state <= S_PAGE_CMD00;
                        end else begin
                            words_in_page <= words_in_page - 10'd1;
                            state <= S_READ_BYTE;
                        end
                    end
                end

                S_DONE: begin
                    nand_ce_n <= 1'b1;
                    nand_re_n <= 1'b1;
                    nand_we_n <= 1'b1;
                    nand_wp_n <= 1'b1;
                    nand_cle <= 1'b0;
                    nand_ale <= 1'b0;
                    nand_d_oe_reg <= 1'b0;
                    boot_done <= 1'b1;
                    state <= S_DONE;
                end

                S_ERROR: begin
                    nand_ce_n <= 1'b1;
                    nand_re_n <= 1'b1;
                    nand_we_n <= 1'b1;
                    nand_wp_n <= 1'b1;
                    nand_cle <= 1'b0;
                    nand_ale <= 1'b0;
                    nand_d_oe_reg <= 1'b0;
                    boot_error <= 1'b1;
                    state <= S_ERROR;
                end

                S_WAIT_READY: begin
                    if (wait_count < MIN_READY_WAIT_CYCLES) begin
                        wait_count <= wait_count + 32'd1;
                    end else if (nand_rdy) begin
                        state <= wait_return;
                    end else if (timeout_count >= timeout_limit) begin
                        state <= S_ERROR;
                    end else begin
                        timeout_count <= timeout_count + 32'd1;
                    end
                end

                S_WR_SETUP: begin
                    nand_re_n <= 1'b1;
                    nand_we_n <= 1'b1;
                    nand_cle <= write_cle;
                    nand_ale <= write_ale;
                    nand_d_out <= write_data;
                    nand_d_oe_reg <= 1'b1;
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
                    nand_d_oe_reg <= 1'b0;
                    state <= write_return;
                end

                S_RD_SETUP: begin
                    nand_cle <= 1'b0;
                    nand_ale <= 1'b0;
                    nand_we_n <= 1'b1;
                    nand_re_n <= 1'b1;
                    nand_d_oe_reg <= 1'b0;
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
                    read_sample <= nand_d_i;
                    nand_re_n <= 1'b1;
                    state <= read_return;
                end

                default: state <= S_ERROR;
            endcase
        end
    end
endmodule

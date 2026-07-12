`timescale 1ns / 1ps

module nand_boot_loader #(
    parameter [24:0] BOOT_NAND_START_WORD = 25'd0,
    parameter [31:0] BOOT_LOAD_ADDR = 32'h1c00_0000,
    parameter [31:0] MAX_PAYLOAD_BYTES = 32'd129024,
    parameter [31:0] DDR_TIMEOUT_CYCLES = 32'd25_000_000
) (
    input wire clk,
    input wire rst_n,
    input wire ddr_ready,
    output wire ddr_req_valid,
    input wire ddr_req_ready,
    output wire ddr_req_we,
    output wire [3:0] ddr_req_wstrb,
    output wire [31:0] ddr_req_addr,
    output wire [31:0] ddr_req_wdata,
    input wire ddr_resp_valid,
    input wire [31:0] ddr_resp_rdata,
    output reg read_req_valid,
    input wire read_req_ready,
    output reg [24:0] read_word_index,
    output reg [31:0] read_word_count,
    input wire read_data_valid,
    output wire read_data_ready,
    input wire [31:0] read_data,
    input wire read_done,
    input wire read_error,
    output reg boot_done,
    output reg boot_error,
    output reg [31:0] boot_status
);
    localparam [31:0] HEADER_MAGIC = 32'h4e42_4f54;
    localparam [31:0] HEADER_VERSION = 32'd1;
    localparam [31:0] STATUS_WAIT_DDR = 32'hb001_0000;
    localparam [31:0] STATUS_HEADER = 32'hb002_0000;
    localparam [31:0] STATUS_COPY = 32'hb003_0000;
    localparam [31:0] STATUS_DONE = 32'hb007_0000;
    localparam [31:0] ERROR_DDR_READY = 32'hbad0_0001;
    localparam [31:0] ERROR_NAND = 32'hbad0_0002;
    localparam [31:0] ERROR_HEADER = 32'hbad0_0003;
    localparam [31:0] ERROR_DDR_WRITE = 32'hbad0_0004;
    localparam [31:0] ERROR_CRC = 32'hbad0_0005;

    localparam [3:0] S_WAIT_DDR = 4'd0;
    localparam [3:0] S_HEADER_REQ = 4'd1;
    localparam [3:0] S_HEADER_DATA = 4'd2;
    localparam [3:0] S_HEADER_CHECK = 4'd3;
    localparam [3:0] S_PAYLOAD_REQ = 4'd4;
    localparam [3:0] S_PAYLOAD_DATA = 4'd5;
    localparam [3:0] S_DDR_REQ = 4'd6;
    localparam [3:0] S_DDR_WAIT = 4'd7;
    localparam [3:0] S_CRC_CHECK = 4'd8;
    localparam [3:0] S_DONE = 4'd9;
    localparam [3:0] S_ERROR = 4'd10;

    reg [3:0] state;
    reg [3:0] header_index;
    reg [31:0] timeout_count;
    reg [31:0] header_magic;
    reg [31:0] header_version;
    reg [31:0] header_payload_bytes;
    reg [31:0] header_load_addr;
    reg [31:0] header_entry_addr;
    reg [31:0] header_crc;
    reg [31:0] header_flags;
    reg [31:0] header_reserved;
    reg [31:0] payload_bytes_done;
    reg [31:0] ddr_addr;
    reg [31:0] pending_word;
    reg [3:0] pending_wstrb;
    reg [2:0] pending_bytes;
    wire [31:0] crc_value;

    wire [31:0] payload_remaining = header_payload_bytes - payload_bytes_done;
    wire [2:0] transfer_bytes = (payload_remaining >= 32'd4) ?
                                3'd4 : payload_remaining[2:0];
    wire [3:0] transfer_wstrb = (transfer_bytes == 3'd4) ? 4'b1111 :
                                (transfer_bytes == 3'd3) ? 4'b0111 :
                                (transfer_bytes == 3'd2) ? 4'b0011 : 4'b0001;

    assign ddr_req_valid = (state == S_DDR_REQ);
    assign ddr_req_we = 1'b1;
    assign ddr_req_wstrb = pending_wstrb;
    assign ddr_req_addr = ddr_addr;
    assign ddr_req_wdata = pending_word;
    assign read_data_ready = (state == S_HEADER_DATA) ||
                             (state == S_PAYLOAD_DATA);

    crc32_stream u_crc32 (
        .clk(clk),
        .rst_n(rst_n),
        .clear(state == S_HEADER_CHECK),
        .data_valid((state == S_PAYLOAD_DATA) && read_data_valid),
        .data(read_data),
        .data_wstrb(transfer_wstrb),
        .value(crc_value)
    );

    task enter_error;
        input [31:0] error_code;
        begin
            boot_status <= error_code;
            state <= S_ERROR;
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_WAIT_DDR;
            header_index <= 4'd0;
            timeout_count <= 32'd0;
            header_magic <= 32'd0;
            header_version <= 32'd0;
            header_payload_bytes <= 32'd0;
            header_load_addr <= 32'd0;
            header_entry_addr <= 32'd0;
            header_crc <= 32'd0;
            header_flags <= 32'd0;
            header_reserved <= 32'd0;
            payload_bytes_done <= 32'd0;
            ddr_addr <= BOOT_LOAD_ADDR;
            pending_word <= 32'd0;
            pending_wstrb <= 4'd0;
            pending_bytes <= 3'd0;
            read_req_valid <= 1'b0;
            read_word_index <= BOOT_NAND_START_WORD;
            read_word_count <= 32'd0;
            boot_done <= 1'b0;
            boot_error <= 1'b0;
            boot_status <= STATUS_WAIT_DDR;
        end else begin
            if (read_req_valid && read_req_ready)
                read_req_valid <= 1'b0;

            case (state)
                S_WAIT_DDR: begin
                    if (ddr_ready) begin
                        timeout_count <= 32'd0;
                        boot_status <= STATUS_HEADER;
                        state <= S_HEADER_REQ;
                    end else if (timeout_count >= DDR_TIMEOUT_CYCLES) begin
                        enter_error(ERROR_DDR_READY);
                    end else begin
                        timeout_count <= timeout_count + 32'd1;
                    end
                end
                S_HEADER_REQ: begin
                    read_word_index <= BOOT_NAND_START_WORD;
                    read_word_count <= 32'd8;
                    read_req_valid <= 1'b1;
                    header_index <= 4'd0;
                    state <= S_HEADER_DATA;
                end
                S_HEADER_DATA: begin
                    if (read_error) begin
                        enter_error(ERROR_NAND);
                    end else begin
                        if (read_data_valid) begin
                            case (header_index)
                                4'd0: header_magic <= read_data;
                                4'd1: header_version <= read_data;
                                4'd2: header_payload_bytes <= read_data;
                                4'd3: header_load_addr <= read_data;
                                4'd4: header_entry_addr <= read_data;
                                4'd5: header_crc <= read_data;
                                4'd6: header_flags <= read_data;
                                default: header_reserved <= read_data;
                            endcase
                            header_index <= header_index + 4'd1;
                        end
                        if (read_done)
                            state <= S_HEADER_CHECK;
                    end
                end
                S_HEADER_CHECK: begin
                    if ((header_magic != HEADER_MAGIC) ||
                        (header_version != HEADER_VERSION) ||
                        (header_payload_bytes == 32'd0) ||
                        (header_payload_bytes > MAX_PAYLOAD_BYTES) ||
                        (header_load_addr != BOOT_LOAD_ADDR) ||
                        (header_entry_addr != BOOT_LOAD_ADDR) ||
                        (header_flags != 32'd0) ||
                        (header_reserved != 32'd0)) begin
                        enter_error(ERROR_HEADER);
                    end else begin
                        payload_bytes_done <= 32'd0;
                        ddr_addr <= BOOT_LOAD_ADDR;
                        boot_status <= STATUS_COPY;
                        state <= S_PAYLOAD_REQ;
                    end
                end
                S_PAYLOAD_REQ: begin
                    read_word_index <= (BOOT_NAND_START_WORD & 25'h1ff_fe00) +
                                       25'd512;
                    read_word_count <= (header_payload_bytes + 32'd3) >> 2;
                    read_req_valid <= 1'b1;
                    state <= S_PAYLOAD_DATA;
                end
                S_PAYLOAD_DATA: begin
                    if (read_error) begin
                        enter_error(ERROR_NAND);
                    end else if (read_data_valid) begin
                        pending_word <= read_data;
                        pending_bytes <= transfer_bytes;
                        pending_wstrb <= transfer_wstrb;
                        timeout_count <= 32'd0;
                        state <= S_DDR_REQ;
                    end
                end
                S_DDR_REQ: begin
                    if (ddr_req_ready) begin
                        timeout_count <= 32'd0;
                        state <= S_DDR_WAIT;
                    end else if (timeout_count >= DDR_TIMEOUT_CYCLES) begin
                        enter_error(ERROR_DDR_WRITE);
                    end else begin
                        timeout_count <= timeout_count + 32'd1;
                    end
                end
                S_DDR_WAIT: begin
                    if (ddr_resp_valid) begin
                        payload_bytes_done <= payload_bytes_done + pending_bytes;
                        ddr_addr <= ddr_addr + 32'd4;
                        boot_status <= STATUS_COPY |
                                       (payload_bytes_done + pending_bytes);
                        if ((payload_bytes_done + pending_bytes) >=
                            header_payload_bytes)
                            state <= S_CRC_CHECK;
                        else
                            state <= S_PAYLOAD_DATA;
                    end else if (timeout_count >= DDR_TIMEOUT_CYCLES) begin
                        enter_error(ERROR_DDR_WRITE);
                    end else begin
                        timeout_count <= timeout_count + 32'd1;
                    end
                end
                S_CRC_CHECK: begin
                    if ((crc_value ^ 32'hffff_ffff) == header_crc) begin
                        boot_status <= STATUS_DONE;
                        state <= S_DONE;
                    end else begin
                        enter_error(ERROR_CRC);
                    end
                end
                S_DONE: begin
                    boot_done <= 1'b1;
                    state <= S_DONE;
                end
                S_ERROR: begin
                    boot_error <= 1'b1;
                    state <= S_ERROR;
                end
                default: enter_error(ERROR_NAND);
            endcase
        end
    end
endmodule

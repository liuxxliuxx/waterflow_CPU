`timescale 1ns / 1ps

module nand_mmio_ctrl(
    input  wire        clk,
    input  wire        rst,
    output wire        mmio_req_ready,
    input  wire        mmio_req_valid,
    input  wire        mmio_req_we,
    input  wire [7:0]  mmio_req_addr,
    input  wire [3:0]  mmio_req_wstrb,
    input  wire [31:0] mmio_req_wdata,
    output reg         mmio_resp_valid,
    input  wire        mmio_resp_ready,
    output reg  [31:0] mmio_resp_rdata,
    output reg         mmio_resp_err,
    output reg         read_req_valid,
    input  wire        read_req_ready,
    output reg  [24:0] read_word_index,
    output wire [31:0] read_word_count,
    input  wire        read_data_valid,
    output wire        read_data_ready,
    input  wire [31:0] read_data,
    input  wire        read_done,
    input  wire        read_error
);
    reg busy;
    reg word_valid;
    reg error;
    reg [31:0] current_word;

    assign mmio_req_ready = !mmio_resp_valid || mmio_resp_ready;
    assign read_word_count = 32'd1;
    assign read_data_ready = 1'b1;

    always @(posedge clk) begin
        if (rst) begin
            mmio_resp_valid <= 1'b0;
            mmio_resp_rdata <= 32'd0;
            mmio_resp_err <= 1'b0;
            read_req_valid <= 1'b0;
            read_word_index <= 25'd0;
            busy <= 1'b0;
            word_valid <= 1'b0;
            error <= 1'b0;
            current_word <= 32'd0;
        end else begin
            if (mmio_resp_valid && mmio_resp_ready) begin
                mmio_resp_valid <= 1'b0;
                mmio_resp_err <= 1'b0;
            end

            if (read_req_valid && read_req_ready)
                read_req_valid <= 1'b0;

            if (read_data_valid) begin
                current_word <= read_data;
                word_valid <= 1'b1;
            end

            if (read_done)
                busy <= 1'b0;

            if (read_error) begin
                busy <= 1'b0;
                error <= 1'b1;
            end

            if (mmio_req_valid && mmio_req_ready) begin
                mmio_resp_valid <= 1'b1;
                mmio_resp_err <= 1'b0;

                case (mmio_req_addr)
                    8'h00: begin
                        mmio_resp_rdata <= {28'd0, 1'b1, error,
                                            word_valid, busy};
                        if (mmio_req_we && mmio_req_wstrb[0] &&
                            mmio_req_wdata[0] && !busy) begin
                            read_word_index <= read_word_index + 25'd1;
                            read_req_valid <= 1'b1;
                            busy <= 1'b1;
                            word_valid <= 1'b0;
                            error <= 1'b0;
                        end
                    end
                    8'h04: begin
                        mmio_resp_rdata <= current_word;
                        if (mmio_req_we)
                            mmio_resp_err <= 1'b1;
                    end
                    8'h08: begin
                        mmio_resp_rdata <= {7'd0, read_word_index};
                        if (mmio_req_we && |mmio_req_wstrb && !busy) begin
                            read_word_index <= mmio_req_wdata[24:0];
                            read_req_valid <= 1'b1;
                            busy <= 1'b1;
                            word_valid <= 1'b0;
                            error <= 1'b0;
                        end
                    end
                    default: begin
                        mmio_resp_rdata <= 32'd0;
                        mmio_resp_err <= 1'b1;
                    end
                endcase
            end
        end
    end
endmodule

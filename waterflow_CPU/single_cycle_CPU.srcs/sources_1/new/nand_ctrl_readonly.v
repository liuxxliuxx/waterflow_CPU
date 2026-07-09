`timescale 1ns/1ps

module nand_ctrl_readonly #(
    parameter [24:0] INITIAL_WORD_INDEX = 25'd0,
    parameter        POWERUP_WAIT_CYCLES = 1024,
    parameter        MIN_READY_WAIT_CYCLES = 8,
    parameter        RESET_TIMEOUT_CYCLES = 25000000,
    parameter        READ_TIMEOUT_CYCLES = 25000000
)(
    input wire clk,
    input wire rst,
    output wire mmio_req_ready,
    input wire mmio_req_valid,
    input wire mmio_req_we,
    input wire [7:0] mmio_req_addr,
    input wire [3:0] mmio_req_wstrb,
    input wire [31:0] mmio_req_wdata,
    output reg mmio_resp_valid,
    input wire mmio_resp_ready,
    output reg [31:0] mmio_resp_rdata,
    output wire mmio_resp_err,
    inout wire [7:0] nand_d,
    output wire nand_cle,
    output wire nand_ale,
    output wire nand_ce_n,
    output wire nand_re_n,
    output wire nand_we_n,
    output wire nand_wp_n,
    input wire nand_rdy
);
    wire [31:0] current_word;
    wire [24:0] word_index;
    wire word_valid;
    wire busy;
    wire error;
    reg step_pulse;
    reg set_index_pulse;
    reg [24:0] set_word_index;

    wire req_fire = mmio_req_valid && mmio_req_ready;

    assign mmio_req_ready = !mmio_resp_valid || mmio_resp_ready;
    assign mmio_resp_err = mmio_resp_valid && error;

    nand_val_core #(
        .INITIAL_WORD_INDEX(INITIAL_WORD_INDEX),
        .POWERUP_WAIT_CYCLES(POWERUP_WAIT_CYCLES),
        .MIN_READY_WAIT_CYCLES(MIN_READY_WAIT_CYCLES),
        .RESET_TIMEOUT_CYCLES(RESET_TIMEOUT_CYCLES),
        .READ_TIMEOUT_CYCLES(READ_TIMEOUT_CYCLES)
    ) u_core (
        .clk(clk),
        .rst(rst),
        .step_pulse(step_pulse),
        .set_index_pulse(set_index_pulse),
        .set_word_index(set_word_index),
        .nand_d(nand_d),
        .nand_cle(nand_cle),
        .nand_ale(nand_ale),
        .nand_ce_n(nand_ce_n),
        .nand_re_n(nand_re_n),
        .nand_we_n(nand_we_n),
        .nand_wp_n(nand_wp_n),
        .nand_rdy(nand_rdy),
        .current_word(current_word),
        .word_index(word_index),
        .word_valid(word_valid),
        .busy(busy),
        .error(error)
    );

    always @(posedge clk) begin
        if (rst) begin
            mmio_resp_valid <= 1'b0;
            mmio_resp_rdata <= 32'h0;
            step_pulse <= 1'b0;
            set_index_pulse <= 1'b0;
            set_word_index <= INITIAL_WORD_INDEX;
        end else begin
            step_pulse <= 1'b0;
            set_index_pulse <= 1'b0;

            if (mmio_resp_valid && mmio_resp_ready)
                mmio_resp_valid <= 1'b0;

            if (req_fire) begin
                if (mmio_req_we && mmio_req_addr == 8'h00 &&
                    mmio_req_wdata[0] && mmio_req_wstrb[0] && !busy && !error) begin
                    step_pulse <= 1'b1;
                end

                if (mmio_req_we && mmio_req_addr == 8'h08 &&
                    |mmio_req_wstrb && !busy && !error) begin
                    set_word_index <= mmio_req_wdata[24:0];
                    set_index_pulse <= 1'b1;
                end

                case (mmio_req_addr)
                    8'h00: mmio_resp_rdata <= {28'h0, nand_rdy, error, word_valid, busy};
                    8'h04: mmio_resp_rdata <= current_word;
                    8'h08: mmio_resp_rdata <= {7'h0, word_index};
                    default: mmio_resp_rdata <= 32'h0;
                endcase

                mmio_resp_valid <= 1'b1;
            end
        end
    end
endmodule

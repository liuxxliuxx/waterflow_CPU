`timescale 1ns / 1ps

module nand_controller #(
    parameter [24:0] BOOT_NAND_START_WORD = 25'd0,
    parameter [31:0] BOOT_LOAD_ADDR = 32'h1c00_0000,
    parameter [31:0] BOOT_MAX_PAYLOAD_BYTES = 32'd8386560
) (
    input wire clk,
    input wire rst_n,
    input wire boot_ddr_ready,
    output wire boot_req_valid,
    input wire boot_req_ready,
    output wire boot_req_we,
    output wire [3:0] boot_req_wstrb,
    output wire [31:0] boot_req_addr,
    output wire [31:0] boot_req_wdata,
    input wire boot_resp_valid,
    input wire [31:0] boot_resp_rdata,
    output wire boot_done,
    output wire boot_error,
    output wire [31:0] boot_status,
    output wire mmio_req_ready,
    input wire mmio_req_valid,
    input wire mmio_req_we,
    input wire [7:0] mmio_req_addr,
    input wire [3:0] mmio_req_wstrb,
    input wire [31:0] mmio_req_wdata,
    output wire mmio_resp_valid,
    input wire mmio_resp_ready,
    output wire [31:0] mmio_resp_rdata,
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
    wire boot_read_req_valid, boot_read_req_ready;
    wire [24:0] boot_read_word_index;
    wire [31:0] boot_read_word_count;
    wire boot_read_data_valid, boot_read_data_ready;
    wire [31:0] boot_read_data;
    wire boot_read_done, boot_read_error;
    wire mmio_read_req_valid, mmio_read_req_ready;
    wire [24:0] mmio_read_word_index;
    wire [31:0] mmio_read_word_count;
    wire mmio_read_data_valid, mmio_read_data_ready;
    wire [31:0] mmio_read_data;
    wire mmio_read_done, mmio_read_error;
    wire engine_req_valid, engine_req_ready;
    wire [24:0] engine_word_index;
    wire [31:0] engine_word_count;
    wire engine_data_valid, engine_data_ready;
    wire [31:0] engine_data;
    wire engine_done, engine_error;
    wire [7:0] nand_d_o;
    wire nand_d_oe;

    nand_boot_loader #(
        .BOOT_NAND_START_WORD(BOOT_NAND_START_WORD),
        .BOOT_LOAD_ADDR(BOOT_LOAD_ADDR),
        .MAX_PAYLOAD_BYTES(BOOT_MAX_PAYLOAD_BYTES)
    ) u_boot (
        .clk(clk), .rst_n(rst_n), .ddr_ready(boot_ddr_ready),
        .ddr_req_valid(boot_req_valid), .ddr_req_ready(boot_req_ready),
        .ddr_req_we(boot_req_we), .ddr_req_wstrb(boot_req_wstrb),
        .ddr_req_addr(boot_req_addr), .ddr_req_wdata(boot_req_wdata),
        .ddr_resp_valid(boot_resp_valid), .ddr_resp_rdata(boot_resp_rdata),
        .read_req_valid(boot_read_req_valid), .read_req_ready(boot_read_req_ready),
        .read_word_index(boot_read_word_index), .read_word_count(boot_read_word_count),
        .read_data_valid(boot_read_data_valid), .read_data_ready(boot_read_data_ready),
        .read_data(boot_read_data), .read_done(boot_read_done),
        .read_error(boot_read_error), .boot_done(boot_done),
        .boot_error(boot_error), .boot_status(boot_status)
    );

    nand_mmio_ctrl u_mmio (
        .clk(clk), .rst(!rst_n), .mmio_req_ready(mmio_req_ready),
        .mmio_req_valid(mmio_req_valid), .mmio_req_we(mmio_req_we),
        .mmio_req_addr(mmio_req_addr), .mmio_req_wstrb(mmio_req_wstrb),
        .mmio_req_wdata(mmio_req_wdata), .mmio_resp_valid(mmio_resp_valid),
        .mmio_resp_ready(mmio_resp_ready), .mmio_resp_rdata(mmio_resp_rdata),
        .mmio_resp_err(mmio_resp_err), .read_req_valid(mmio_read_req_valid),
        .read_req_ready(mmio_read_req_ready), .read_word_index(mmio_read_word_index),
        .read_word_count(mmio_read_word_count), .read_data_valid(mmio_read_data_valid),
        .read_data_ready(mmio_read_data_ready), .read_data(mmio_read_data),
        .read_done(mmio_read_done), .read_error(mmio_read_error)
    );

    // Boot owns the shared reader until boot_done; MMIO owns it afterwards.
    assign engine_req_valid = boot_done ?
                              mmio_read_req_valid : boot_read_req_valid;
    assign engine_word_index = boot_done ?
                               mmio_read_word_index : boot_read_word_index;
    assign engine_word_count = boot_done ?
                               mmio_read_word_count : boot_read_word_count;
    assign engine_data_ready = boot_done ?
                               mmio_read_data_ready : boot_read_data_ready;

    assign boot_read_req_ready = !boot_done && engine_req_ready;
    assign boot_read_data_valid = !boot_done && engine_data_valid;
    assign boot_read_data = engine_data;
    assign boot_read_done = !boot_done && engine_done;
    assign boot_read_error = !boot_done && engine_error;

    assign mmio_read_req_ready = boot_done && engine_req_ready;
    assign mmio_read_data_valid = boot_done && engine_data_valid;
    assign mmio_read_data = engine_data;
    assign mmio_read_done = boot_done && engine_done;
    assign mmio_read_error = boot_done && engine_error;

    nand_read_engine u_reader (
        .clk(clk), .rst_n(rst_n), .req_valid(engine_req_valid),
        .req_ready(engine_req_ready), .req_word_index(engine_word_index),
        .req_word_count(engine_word_count), .data_valid(engine_data_valid),
        .data_ready(engine_data_ready), .data(engine_data), .done(engine_done),
        .error(engine_error), .nand_d_i(nand_d), .nand_d_o(nand_d_o),
        .nand_d_oe(nand_d_oe), .nand_cle(nand_cle), .nand_ale(nand_ale),
        .nand_ce_n(nand_ce_n), .nand_re_n(nand_re_n), .nand_we_n(nand_we_n),
        .nand_wp_n(nand_wp_n), .nand_rdy(nand_rdy)
    );

    assign nand_d = nand_d_oe ? nand_d_o : 8'hzz;
endmodule

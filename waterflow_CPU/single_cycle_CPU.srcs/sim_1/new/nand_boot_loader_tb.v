`timescale 1ns / 1ps

// Shared byte-wide NAND model for the production Boot regressions.
module nand_boot_flash_model #(
    parameter integer MEM_BYTES = 4096,
    parameter integer STALL_PAGE_READY = 0
) (
    inout  wire [7:0] nand_d,
    input  wire       nand_cle,
    input  wire       nand_ale,
    input  wire       nand_ce_n,
    input  wire       nand_re_n,
    input  wire       nand_we_n,
    output reg        nand_rdy
);
    reg [7:0] mem [0:MEM_BYTES-1];
    reg [7:0] address_byte [0:4];
    reg [2:0] address_count;
    integer byte_index;
    integer init_index;

    assign nand_d = (!nand_ce_n && !nand_re_n &&
                     (byte_index >= 0) && (byte_index < MEM_BYTES)) ?
                    mem[byte_index] : 8'hzz;

    task fill_ff;
        begin
            for (init_index = 0; init_index < MEM_BYTES;
                 init_index = init_index + 1)
                mem[init_index] = 8'hff;
            address_count = 3'd0;
            byte_index = 0;
            nand_rdy = 1'b1;
        end
    endtask

    task put_word;
        input integer byte_address;
        input [31:0] value;
        begin
            mem[byte_address] = value[7:0];
            mem[byte_address + 1] = value[15:8];
            mem[byte_address + 2] = value[23:16];
            mem[byte_address + 3] = value[31:24];
        end
    endtask

    task put_byte;
        input integer byte_address;
        input [7:0] value;
        begin
            mem[byte_address] = value;
        end
    endtask

    initial begin
        address_count = 3'd0;
        byte_index = 0;
        nand_rdy = 1'b1;
    end

    always @(posedge nand_we_n) begin
        if (!nand_ce_n) begin
            if (nand_cle) begin
                if (nand_d == 8'hff) begin
                    nand_rdy <= 1'b0;
                    address_count <= 3'd0;
                    #20 nand_rdy <= 1'b1;
                end else if (nand_d == 8'h00) begin
                    address_count <= 3'd0;
                end else if (nand_d == 8'h30) begin
                    byte_index <= {address_byte[3], address_byte[2],
                                   address_byte[1][2:0], address_byte[0]};
                    nand_rdy <= 1'b0;
                    if (!STALL_PAGE_READY)
                        #20 nand_rdy <= 1'b1;
                end
            end else if (nand_ale) begin
                address_byte[address_count] <= nand_d;
                address_count <= address_count + 3'd1;
            end
        end
    end

    always @(posedge nand_re_n)
        if (!nand_ce_n)
            byte_index <= byte_index + 1;
endmodule

module nand_boot_loader_tb;
    nand_boot_success_env #(.PAYLOAD_BYTES(2051)) env();
endmodule

module nand_boot_loader_max_tb;
    nand_boot_success_env #(.PAYLOAD_BYTES(129024)) env();
endmodule

module nand_boot_success_env #(
    parameter integer PAYLOAD_BYTES = 2051
);
    localparam integer NAND_MEM_BYTES = 2048 + PAYLOAD_BYTES + 4;
    localparam integer DDR_MEM_BYTES = PAYLOAD_BYTES + 4;
    localparam integer EXPECTED_WRITES = (PAYLOAD_BYTES + 3) / 4;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg ddr_ready = 1'b0;
    tri [7:0] nand_d;
    wire [7:0] nand_d_o;
    wire nand_d_oe;
    wire nand_cle, nand_ale, nand_ce_n, nand_re_n, nand_we_n, nand_wp_n;
    wire nand_rdy;
    wire ddr_req_valid, ddr_req_ready, ddr_req_we;
    wire [3:0] ddr_req_wstrb;
    wire [31:0] ddr_req_addr, ddr_req_wdata;
    reg ddr_resp_valid;
    wire boot_done, boot_error;
    wire [31:0] boot_status;

    reg [7:0] ddr_mem [0:DDR_MEM_BYTES-1];
    reg ddr_pending;
    integer write_count;
    integer i;
    integer ddr_offset;
    reg [31:0] image_crc;

    always #5 clk = ~clk;
    assign nand_d = nand_d_oe ? nand_d_o : 8'hzz;
    assign ddr_req_ready = !ddr_pending;

    function [7:0] payload_byte;
        input integer index;
        begin
            payload_byte = ((index * 37) + 11) & 8'hff;
        end
    endfunction

    function [31:0] crc32_byte;
        input [31:0] crc_in;
        input [7:0] data;
        integer k;
        reg [31:0] value;
        begin
            value = crc_in ^ {24'd0, data};
            for (k = 0; k < 8; k = k + 1)
                value = value[0] ? ((value >> 1) ^ 32'hedb8_8320) :
                                   (value >> 1);
            crc32_byte = value;
        end
    endfunction

    nand_boot_flash_model #(
        .MEM_BYTES(NAND_MEM_BYTES)
    ) nand_model (
        .nand_d(nand_d), .nand_cle(nand_cle), .nand_ale(nand_ale),
        .nand_ce_n(nand_ce_n), .nand_re_n(nand_re_n),
        .nand_we_n(nand_we_n), .nand_rdy(nand_rdy)
    );

    nand_boot_loader #(
        .DDR_TIMEOUT_CYCLES(32'd64),
        .RESET_TIMEOUT_CYCLES(32'd64),
        .READ_TIMEOUT_CYCLES(32'd64),
        .MIN_READY_WAIT_CYCLES(32'd1)
    ) dut (
        .clk(clk), .rst_n(rst_n), .ddr_ready(ddr_ready),
        .ddr_req_valid(ddr_req_valid), .ddr_req_ready(ddr_req_ready),
        .ddr_req_we(ddr_req_we), .ddr_req_wstrb(ddr_req_wstrb),
        .ddr_req_addr(ddr_req_addr), .ddr_req_wdata(ddr_req_wdata),
        .ddr_resp_valid(ddr_resp_valid), .ddr_resp_rdata(32'd0),
        .nand_d_i(nand_d), .nand_d_o(nand_d_o), .nand_d_oe(nand_d_oe),
        .nand_cle(nand_cle), .nand_ale(nand_ale), .nand_ce_n(nand_ce_n),
        .nand_re_n(nand_re_n), .nand_we_n(nand_we_n),
        .nand_wp_n(nand_wp_n), .nand_rdy(nand_rdy),
        .boot_done(boot_done), .boot_error(boot_error),
        .boot_status(boot_status)
    );

    always @(posedge clk) begin
        ddr_resp_valid <= 1'b0;
        if (ddr_req_valid && ddr_req_ready) begin
            if (!ddr_req_we)
                $fatal(1, "boot loader issued a DDR read");
            if (ddr_req_addr !== (32'h1c00_0000 + write_count * 4))
                $fatal(1, "non-sequential DDR address %h at write %0d",
                       ddr_req_addr, write_count);
            ddr_offset = ddr_req_addr - 32'h1c00_0000;
            if (ddr_req_wstrb[0]) ddr_mem[ddr_offset] <= ddr_req_wdata[7:0];
            if (ddr_req_wstrb[1]) ddr_mem[ddr_offset + 1] <= ddr_req_wdata[15:8];
            if (ddr_req_wstrb[2]) ddr_mem[ddr_offset + 2] <= ddr_req_wdata[23:16];
            if (ddr_req_wstrb[3]) ddr_mem[ddr_offset + 3] <= ddr_req_wdata[31:24];
            write_count <= write_count + 1;
            ddr_pending <= 1'b1;
        end else if (ddr_pending) begin
            ddr_pending <= 1'b0;
            ddr_resp_valid <= 1'b1;
        end
    end

    initial begin
        nand_model.fill_ff();
        for (i = 0; i < DDR_MEM_BYTES; i = i + 1)
            ddr_mem[i] = 8'h00;

        image_crc = 32'hffff_ffff;
        for (i = 0; i < PAYLOAD_BYTES; i = i + 1) begin
            nand_model.put_byte(2048 + i, payload_byte(i));
            image_crc = crc32_byte(image_crc, payload_byte(i));
        end
        image_crc = image_crc ^ 32'hffff_ffff;

        nand_model.put_word(0, 32'h4e42_4f54);
        nand_model.put_word(4, 32'd1);
        nand_model.put_word(8, PAYLOAD_BYTES);
        nand_model.put_word(12, 32'h1c00_0000);
        nand_model.put_word(16, 32'h1c00_0000);
        nand_model.put_word(20, image_crc);
        nand_model.put_word(24, 32'd0);
        nand_model.put_word(28, 32'd0);

        ddr_pending = 1'b0;
        ddr_resp_valid = 1'b0;
        write_count = 0;

        #25 rst_n = 1'b1;
        #25 ddr_ready = 1'b1;
        wait (boot_done || boot_error);
        #20;
        if (boot_error)
            $fatal(1, "unexpected boot error, status=%h", boot_status);
        if (boot_status !== 32'hb007_0000)
            $fatal(1, "wrong completion status: %h", boot_status);
        if (write_count != EXPECTED_WRITES)
            $fatal(1, "expected %0d single-pass writes, got %0d",
                   EXPECTED_WRITES, write_count);
        for (i = 0; i < PAYLOAD_BYTES; i = i + 1)
            if (ddr_mem[i] !== payload_byte(i))
                $fatal(1, "DDR mismatch at byte %0d: %h", i, ddr_mem[i]);
        if (ddr_mem[PAYLOAD_BYTES] !== 8'h00)
            $fatal(1, "partial final word overwrote byte after payload");
        $display("PASS: production Boot copied %0d bytes once", PAYLOAD_BYTES);
        $finish;
    end

    initial begin
        #50_000_000;
        $fatal(1, "success simulation timeout for %0d bytes", PAYLOAD_BYTES);
    end
endmodule

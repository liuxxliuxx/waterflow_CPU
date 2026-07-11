`timescale 1ns / 1ps

// CPU-only regression for the first part of tools/nand_led_vga_demo.bin.
// It supplies the exact reset/startup/main/led_write instructions and checks
// that the program stores 8'hca to the LED MMIO register.
module cpu_nand_led_demo_tb;
    reg clk = 1'b0;
    reg rst = 1'b0;

    wire        inst_req_valid;
    wire        inst_req_ready;
    wire [31:0] inst_req_vaddr;
    reg         inst_resp_valid = 1'b0;
    reg  [31:0] inst_resp_data = 32'h0;

    wire        data_req_valid;
    wire        data_req_ready;
    wire        data_req_we;
    wire [31:0] data_req_vaddr;
    wire [31:0] data_req_wdata;
    wire [3:0]  data_req_wstrb;
    wire [1:0]  data_req_size;
    reg         data_resp_valid = 1'b0;
    reg  [31:0] data_resp_rdata = 32'h0;

    reg        inst_pending;
    reg [31:0] inst_pending_data;
    reg        data_pending;
    reg        saw_led_write;
    integer    cycles;

    assign inst_req_ready = !inst_pending && !inst_resp_valid;
    assign data_req_ready = !data_pending && !data_resp_valid;

    always #20 clk = ~clk;

    function [31:0] instruction_at;
        input [31:0] address;
        begin
            case (address)
                // crt0.S
                32'h1c00_0000: instruction_at = 32'h1439_ffe3;
                32'h1c00_0004: instruction_at = 32'h1c00_000c;
                32'h1c00_0008: instruction_at = 32'h028b_a18c;
                32'h1c00_000c: instruction_at = 32'h1c00_000d;
                32'h1c00_0010: instruction_at = 32'h028b_81ad;
                32'h1c00_0014: instruction_at = 32'h5800_118d;
                32'h1c00_0018: instruction_at = 32'h2980_0180;
                32'h1c00_001c: instruction_at = 32'h0280_118c;
                32'h1c00_0020: instruction_at = 32'h53ff_f7ff;
                32'h1c00_0024: instruction_at = 32'h5402_9000;
                32'h1c00_0028: instruction_at = 32'h5000_0000;

                // main
                32'h1c00_02b4: instruction_at = 32'h02bf_c063;
                32'h1c00_02b8: instruction_at = 32'h0283_2804;
                32'h1c00_02bc: instruction_at = 32'h2980_3061;
                32'h1c00_02c0: instruction_at = 32'h57ff_dbff;
                32'h1c00_02c4: instruction_at = 32'h57fd_6bff;
                32'h1c00_02c8: instruction_at = 32'h1c00_0006;
                32'h1c00_02cc: instruction_at = 32'h0280_60c6;
                32'h1c00_02d0: instruction_at = 32'h0015_0005;
                32'h1c00_02d4: instruction_at = 32'h0015_0004;
                32'h1c00_02d8: instruction_at = 32'h57fd_dfff;
                32'h1c00_02dc: instruction_at = 32'h5000_0000;

                // led_write
                32'h1c00_0298: instruction_at = 32'h143f_cc0c;
                32'h1c00_029c: instruction_at = 32'h2980_0184;
                32'h1c00_02a0: instruction_at = 32'h4c00_0020;

                default: instruction_at = 32'h0340_0000; // ori r0, r0, 0
            endcase
        end
    endfunction

    CPU u_cpu (
        .clk(clk),
        .rst(rst),
        .test_addr(5'd0),
        .test_data(),
        .test_pc_cur(),
        .test_inst(),
        .inst_req_valid(inst_req_valid),
        .inst_req_ready(inst_req_ready),
        .inst_req_vaddr(inst_req_vaddr),
        .inst_resp_valid(inst_resp_valid),
        .inst_resp_data(inst_resp_data),
        .inst_resp_err(1'b0),
        .data_req_valid(data_req_valid),
        .data_req_ready(data_req_ready),
        .data_req_we(data_req_we),
        .data_req_vaddr(data_req_vaddr),
        .data_req_wdata(data_req_wdata),
        .data_req_wstrb(data_req_wstrb),
        .data_req_size(data_req_size),
        .data_resp_valid(data_resp_valid),
        .data_resp_rdata(data_resp_rdata),
        .data_resp_err(1'b0),
        .hw_int(8'h00)
    );

    always @(posedge clk) begin
        if (!rst) begin
            inst_pending <= 1'b0;
            inst_pending_data <= 32'h0;
            inst_resp_valid <= 1'b0;
            inst_resp_data <= 32'h0;
        end else begin
            inst_resp_valid <= 1'b0;
            if (inst_pending) begin
                inst_resp_data <= inst_pending_data;
                inst_resp_valid <= 1'b1;
                inst_pending <= 1'b0;
            end
            if (inst_req_valid && inst_req_ready) begin
                inst_pending_data <= instruction_at(inst_req_vaddr);
                inst_pending <= 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if (!rst) begin
            data_pending <= 1'b0;
            data_resp_valid <= 1'b0;
            data_resp_rdata <= 32'h0;
            saw_led_write <= 1'b0;
        end else begin
            data_resp_valid <= 1'b0;
            if (data_pending) begin
                data_resp_valid <= 1'b1;
                data_resp_rdata <= 32'h0;
                data_pending <= 1'b0;
            end
            if (data_req_valid && data_req_ready) begin
                data_pending <= 1'b1;
                if (data_req_we && data_req_vaddr == 32'h1fe6_0000 &&
                    data_req_wdata[7:0] == 8'hca && data_req_wstrb == 4'b1111) begin
                    saw_led_write <= 1'b1;
                end
            end
        end
    end

    initial begin
        inst_pending = 1'b0;
        inst_pending_data = 32'h0;
        data_pending = 1'b0;
        saw_led_write = 1'b0;
        cycles = 0;

        #100 rst = 1'b1;
        while (!saw_led_write && cycles < 1000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        if (!saw_led_write) begin
            $fatal(1, "nand LED demo never wrote 8'hca to LED MMIO");
        end
        $display("PASS: NAND LED demo executed led_write(8'hca)");
        $finish;
    end
endmodule

`timescale 1ns / 1ps

module nand_boot_loader_tb;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg ddr_ready = 1'b0;
    tri [7:0] nand_d;
    wire [7:0] nand_d_o;
    wire nand_d_oe;
    wire nand_cle, nand_ale, nand_ce_n, nand_re_n, nand_we_n, nand_wp_n;
    wire ddr_req_valid;
    wire ddr_req_ready;
    wire [31:0] ddr_req_addr;
    wire [31:0] ddr_req_wdata;
    reg ddr_resp_valid;
    wire boot_done;
    wire boot_error;

    reg [31:0] ddr_mem [0:7];
    reg ddr_pending;
    reg [2:0] ddr_word_addr;
    reg [7:0] nand_mem [0:4095];
    reg nand_rdy;
    reg [7:0] nand_addr [0:4];
    reg [2:0] nand_addr_count;
    reg [24:0] nand_word_index;
    integer nand_byte_index;
    integer i;

    always #5 clk = ~clk;
    assign nand_d = nand_d_oe ? nand_d_o : 8'hzz;
    assign nand_d = (!nand_ce_n && !nand_re_n) ? nand_mem[nand_byte_index] : 8'hzz;
    assign ddr_req_ready = !ddr_pending;

    nand_boot_loader #(
        .BOOT_NAND_START_WORD(25'd511),
        .BOOT_WORDS(32'd6),
        .RESET_TIMEOUT_CYCLES(32'd32),
        .READ_TIMEOUT_CYCLES(32'd32),
        .MIN_READY_WAIT_CYCLES(32'd1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .ddr_ready(ddr_ready),
        .ddr_req_valid(ddr_req_valid),
        .ddr_req_ready(ddr_req_ready),
        .ddr_req_addr(ddr_req_addr),
        .ddr_req_wdata(ddr_req_wdata),
        .ddr_resp_valid(ddr_resp_valid),
        .nand_d_i(nand_d),
        .nand_d_o(nand_d_o),
        .nand_d_oe(nand_d_oe),
        .nand_cle(nand_cle),
        .nand_ale(nand_ale),
        .nand_ce_n(nand_ce_n),
        .nand_re_n(nand_re_n),
        .nand_we_n(nand_we_n),
        .nand_wp_n(nand_wp_n),
        .nand_rdy(nand_rdy),
        .boot_done(boot_done),
        .boot_error(boot_error)
    );

    always @(posedge clk) begin
        ddr_resp_valid <= 1'b0;
        if (ddr_req_valid && ddr_req_ready) begin
            ddr_mem[ddr_req_addr[4:2]] <= ddr_req_wdata;
            ddr_word_addr <= ddr_req_addr[4:2];
            ddr_pending <= 1'b1;
        end else if (ddr_pending) begin
            ddr_pending <= 1'b0;
            ddr_resp_valid <= 1'b1;
        end
    end

    always @(posedge nand_we_n) begin
        if (!nand_ce_n) begin
            if (nand_cle) begin
                if (nand_d == 8'hff) begin
                    nand_rdy <= 1'b0;
                    nand_addr_count <= 3'd0;
                    #20 nand_rdy <= 1'b1;
                end else if (nand_d == 8'h00) begin
                    nand_addr_count <= 3'd0;
                end else if (nand_d == 8'h30) begin
                    nand_word_index <= {nand_addr[3], nand_addr[2],
                                        nand_addr[1][2:0], nand_addr[0][7:2]};
                    nand_byte_index <= {nand_addr[3], nand_addr[2],
                                        nand_addr[1][2:0], nand_addr[0][7:2], 2'b00};
                    nand_rdy <= 1'b0;
                    #20 nand_rdy <= 1'b1;
                end
            end else if (nand_ale) begin
                nand_addr[nand_addr_count] <= nand_d;
                nand_addr_count <= nand_addr_count + 3'd1;
            end
        end
    end

    always @(posedge nand_re_n) begin
        if (!nand_ce_n) begin
            nand_byte_index <= nand_byte_index + 1;
        end
    end

    initial begin
        for (i = 0; i < 4096; i = i + 1) nand_mem[i] = 8'hff;
        nand_mem[2044] = 8'h00; nand_mem[2045] = 8'h00; nand_mem[2046] = 8'h40; nand_mem[2047] = 8'h03;
        nand_mem[2048] = 8'h78; nand_mem[2049] = 8'h56; nand_mem[2050] = 8'h34; nand_mem[2051] = 8'h12;
        nand_mem[2052] = 8'hef; nand_mem[2053] = 8'hbe; nand_mem[2054] = 8'had; nand_mem[2055] = 8'hde;
        nand_mem[2056] = 8'hfe; nand_mem[2057] = 8'hca; nand_mem[2058] = 8'had; nand_mem[2059] = 8'h0b;
        nand_mem[2060] = 8'h44; nand_mem[2061] = 8'h33; nand_mem[2062] = 8'h22; nand_mem[2063] = 8'h11;
        nand_mem[2064] = 8'hbe; nand_mem[2065] = 8'hba; nand_mem[2066] = 8'hfe; nand_mem[2067] = 8'hca;
        nand_rdy = 1'b1;
        nand_addr_count = 3'd0;
        nand_word_index = 25'd0;
        nand_byte_index = 0;
        ddr_pending = 1'b0;
        ddr_resp_valid = 1'b0;
        for (i = 0; i < 8; i = i + 1) ddr_mem[i] = 32'h0;
        #25 rst_n = 1'b1;
        #25 ddr_ready = 1'b1;
        wait (boot_done || boot_error);
        #20;
        if (boot_error) $fatal(1, "boot loader entered error state");
        if (ddr_mem[0] !== 32'h0340_0000) $fatal(1, "word 0 mismatch: %h", ddr_mem[0]);
        if (ddr_mem[1] !== 32'h1234_5678) $fatal(1, "word 1 mismatch: %h", ddr_mem[1]);
        if (ddr_mem[2] !== 32'hdead_beef) $fatal(1, "word 2 mismatch: %h", ddr_mem[2]);
        if (ddr_mem[3] !== 32'h0bad_cafe) $fatal(1, "word 3 mismatch: %h", ddr_mem[3]);
        if (ddr_mem[4] !== 32'h1122_3344) $fatal(1, "word 4 mismatch: %h", ddr_mem[4]);
        if (ddr_mem[5] !== 32'hcafe_babe) $fatal(1, "word 5 mismatch: %h", ddr_mem[5]);
        $display("PASS: NAND boot loader copied six words across a page boundary");
        $finish;
    end
endmodule

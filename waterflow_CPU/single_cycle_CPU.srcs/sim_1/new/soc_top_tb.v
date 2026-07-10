`timescale 1ps / 1ps

// End-to-end smoke test: calibration, NAND boot copy, and the CPU's first
// instruction fetch all use the real MIG functional simulation netlist.
module soc_top_tb;
    reg sys_clk_i = 1'b0;
    reg rst_n = 1'b0;
    tri [7:0] nand_d;
    reg [7:0] nand_mem [0:2047];
    reg nand_rdy = 1'b1;
    reg [7:0] nand_addr [0:4];
    reg [2:0] nand_addr_count = 3'd0;
    integer nand_byte_index = 0;
    integer i;

    wire uart_tx;
    wire [7:0] led;
    wire nand_cle, nand_ale, nand_ce_n, nand_re_n, nand_we_n;
    wire [12:0] ddr3_addr;
    wire [2:0] ddr3_ba;
    wire ddr3_cas_n, ddr3_ras_n, ddr3_reset_n, ddr3_we_n;
    wire [0:0] ddr3_ck_n, ddr3_ck_p, ddr3_cke, ddr3_odt;
    tri [15:0] ddr3_dq;
    tri [1:0] ddr3_dqs_n, ddr3_dqs_p;
    wire [1:0] ddr3_dm;
    wire [1:0] ddr3_tdqs_n;

    always #5000 sys_clk_i = ~sys_clk_i;

    soc_top #(
        .BOOT_WORDS(32'd1)
    ) dut (
        .sys_clk_i(sys_clk_i),
        .rst_n(rst_n),
        .uart_tx(uart_tx),
        .uart_rx(1'b1),
        .led(led),
        .nand_d(nand_d),
        .nand_cle(nand_cle),
        .nand_ale(nand_ale),
        .nand_ce_n(nand_ce_n),
        .nand_re_n(nand_re_n),
        .nand_we_n(nand_we_n),
        .nand_rdy(nand_rdy),
        .ddr3_addr(ddr3_addr),
        .ddr3_ba(ddr3_ba),
        .ddr3_cas_n(ddr3_cas_n),
        .ddr3_ck_n(ddr3_ck_n),
        .ddr3_ck_p(ddr3_ck_p),
        .ddr3_cke(ddr3_cke),
        .ddr3_ras_n(ddr3_ras_n),
        .ddr3_reset_n(ddr3_reset_n),
        .ddr3_we_n(ddr3_we_n),
        .ddr3_dq(ddr3_dq),
        .ddr3_dqs_n(ddr3_dqs_n),
        .ddr3_dqs_p(ddr3_dqs_p),
        .ddr3_dm(ddr3_dm),
        .ddr3_odt(ddr3_odt)
    );

    // x16, 1 Gb model configuration matches the generated MIG core.
    ddr3_model u_ddr3_model (
        .rst_n(ddr3_reset_n),
        .ck(ddr3_ck_p[0]),
        .ck_n(ddr3_ck_n[0]),
        .cke(ddr3_cke[0]),
        .cs_n(1'b0),
        .ras_n(ddr3_ras_n),
        .cas_n(ddr3_cas_n),
        .we_n(ddr3_we_n),
        .dm_tdqs(ddr3_dm),
        .ba(ddr3_ba),
        .addr(ddr3_addr),
        .dq(ddr3_dq),
        .dqs(ddr3_dqs_p),
        .dqs_n(ddr3_dqs_n),
        .tdqs_n(ddr3_tdqs_n),
        .odt(ddr3_odt[0])
    );

    // Read-only K9F1G08U0C main-area model. The loader uses only page reads.
    assign nand_d = (!nand_ce_n && !nand_re_n) ? nand_mem[nand_byte_index] : 8'hzz;

    always @(posedge nand_we_n) begin
        if (!nand_ce_n) begin
            if (nand_cle) begin
                if (nand_d == 8'hff) begin
                    nand_rdy <= 1'b0;
                    nand_addr_count <= 3'd0;
                    #20000 nand_rdy <= 1'b1;
                end else if (nand_d == 8'h00) begin
                    nand_addr_count <= 3'd0;
                end else if (nand_d == 8'h30) begin
                    nand_byte_index <= {nand_addr[3], nand_addr[2],
                                        nand_addr[1][2:0], nand_addr[0][7:2],
                                        2'b00};
                    nand_rdy <= 1'b0;
                    #20000 nand_rdy <= 1'b1;
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

    // No request is allowed to enter the memory system while the CPU reset is held.
    always @(posedge dut.ddr_ui_clk) begin
        if (!dut.cpu_rst_n && (dut.u_mem_subsystem.i_req_valid ||
                               dut.u_mem_subsystem.d_req_valid)) begin
            $fatal(1, "CPU request reached mem_subsystem before boot completion");
        end
    end

    initial begin
        for (i = 0; i < 2048; i = i + 1) begin
            nand_mem[i] = 8'hff;
        end
        // LoongArch NOP (ori r0, r0, 0) in little-endian NAND byte order.
        nand_mem[0] = 8'h00;
        nand_mem[1] = 8'h00;
        nand_mem[2] = 8'h40;
        nand_mem[3] = 8'h03;

        #200000 rst_n = 1'b1;
        wait (dut.ddr_init_calib_complete);
        if (dut.cpu_rst_n) begin
            $fatal(1, "CPU left reset before NAND boot was complete");
        end

        wait (dut.boot_done || dut.boot_error);
        if (dut.boot_error) begin
            $fatal(1, "NAND boot loader reported an error");
        end
        if (!dut.cpu_rst_n) begin
            $fatal(1, "CPU remained reset after successful NAND boot");
        end

        wait (dut.u_cpu.u_ifu.out_valid);
        if (dut.u_cpu.u_ifu.out_pc !== 32'h1c00_0000) begin
            $fatal(1, "first CPU fetch address mismatch: %h", dut.u_cpu.u_ifu.out_pc);
        end
        if (dut.u_cpu.u_ifu.out_inst !== 32'h0340_0000) begin
            $fatal(1, "first CPU fetch data mismatch: %h", dut.u_cpu.u_ifu.out_inst);
        end
        $display("PASS: SoC booted NAND word into DDR and CPU fetched it at 1c000000");
        $finish;
    end

    initial begin
        #(64'd3000000000);
        $fatal(1, "SoC boot simulation timed out");
    end
endmodule

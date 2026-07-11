`timescale 1ns / 1ps

module ddr_cdc_bridge_tb;
    reg src_clk = 1'b0;
    reg dst_clk = 1'b0;
    reg src_rst_n = 1'b0;
    reg dst_rst = 1'b1;
    reg src_req_valid = 1'b0;
    reg src_req_we = 1'b0;
    reg [3:0] src_req_wstrb = 4'b0;
    reg [31:0] src_req_addr = 32'b0;
    reg [31:0] src_req_wdata = 32'b0;
    wire src_req_ready;
    wire src_resp_valid;
    wire [31:0] src_resp_rdata;
    wire dst_req_valid;
    wire dst_req_we;
    wire [3:0] dst_req_wstrb;
    wire [31:0] dst_req_addr;
    wire [31:0] dst_req_wdata;
    reg dst_resp_valid = 1'b0;
    reg [31:0] dst_resp_rdata = 32'b0;
    reg dst_response_pending = 1'b0;
    reg [31:0] captured_req = 32'b0;

    always #20 src_clk = ~src_clk;
    always #5 dst_clk = ~dst_clk;

    ddr_cdc_bridge dut (
        .src_clk(src_clk),
        .src_rst_n(src_rst_n),
        .src_req_valid(src_req_valid),
        .src_req_ready(src_req_ready),
        .src_req_we(src_req_we),
        .src_req_wstrb(src_req_wstrb),
        .src_req_addr(src_req_addr),
        .src_req_wdata(src_req_wdata),
        .src_resp_valid(src_resp_valid),
        .src_resp_ready(1'b1),
        .src_resp_rdata(src_resp_rdata),
        .dst_clk(dst_clk),
        .dst_rst(dst_rst),
        .dst_req_valid(dst_req_valid),
        .dst_req_ready(1'b1),
        .dst_req_we(dst_req_we),
        .dst_req_wstrb(dst_req_wstrb),
        .dst_req_addr(dst_req_addr),
        .dst_req_wdata(dst_req_wdata),
        .dst_resp_valid(dst_resp_valid),
        .dst_resp_rdata(dst_resp_rdata)
    );

    always @(posedge dst_clk) begin
        dst_resp_valid <= 1'b0;
        if (dst_req_valid) begin
            if (!dst_req_we || dst_req_wstrb != 4'b1111 ||
                dst_req_addr != 32'h1c00_0000 || dst_req_wdata != 32'h1234_5678) begin
                $fatal(1, "CDC request payload mismatch");
            end
            captured_req <= dst_req_wdata;
            dst_response_pending <= 1'b1;
        end else if (dst_response_pending) begin
            dst_resp_rdata <= captured_req ^ 32'hffff_ffff;
            dst_resp_valid <= 1'b1;
            dst_response_pending <= 1'b0;
        end
    end

    initial begin
        #100 src_rst_n = 1'b1;
        #40 dst_rst = 1'b0;
        @(negedge src_clk);
        src_req_valid = 1'b1;
        src_req_we = 1'b1;
        src_req_wstrb = 4'b1111;
        src_req_addr = 32'h1c00_0000;
        src_req_wdata = 32'h1234_5678;
        @(negedge src_clk);
        src_req_valid = 1'b0;
        wait (src_resp_valid);
        if (src_resp_rdata !== 32'hedcb_a987) begin
            $fatal(1, "CDC response mismatch: %h", src_resp_rdata);
        end
        $display("PASS: 25 MHz SoC request crossed to the DDR UI clock and returned");
        $finish;
    end
endmodule

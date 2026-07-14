`timescale 1ns / 1ps

module vga_text_tb;
    reg cpu_clk = 1'b0;
    reg pix_clk = 1'b0;
    reg rst = 1'b1;
    reg cpu_we = 1'b0;
    reg [11:0] cpu_addr = 12'd0;
    reg [7:0] cpu_wdata = 8'h00;
    wire [7:0] cpu_rdata;
    wire cpu_busy;
    wire [3:0] vga_r;
    wire [3:0] vga_g;
    wire [3:0] vga_b;
    wire hsync;
    wire vsync;
    integer errors = 0;
    integer timeout;

    always #20 cpu_clk = ~cpu_clk;
    always #20 pix_clk = ~pix_clk;

    vga_text u_dut(
        .cpu_clk(cpu_clk),
        .pix_clk(pix_clk),
        .rst(rst),
        .cpu_we(cpu_we),
        .cpu_addr(cpu_addr),
        .cpu_wdata(cpu_wdata),
        .cpu_rdata(cpu_rdata),
        .cpu_busy(cpu_busy),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .hsync(hsync),
        .vsync(vsync)
    );

    task write_char;
        input [11:0] address;
        input [7:0] value;
        begin
            @(negedge cpu_clk);
            cpu_addr = address;
            cpu_wdata = value;
            cpu_we = 1'b1;
            @(negedge cpu_clk);
            cpu_we = 1'b0;
            #1;
        end
    endtask

    initial begin
        repeat (5) @(posedge cpu_clk);
        @(negedge cpu_clk);
        rst = 1'b0;

        write_char(12'd81, "A");
        if (cpu_rdata !== "A") errors = errors + 1;
        write_char(12'd81, "Z");
        if (cpu_rdata !== "Z") errors = errors + 1;

        write_char(12'hffe, "X");
        if (cpu_rdata !== 8'h00 || cpu_busy) begin
            $display("Removed VGA frame command still has an effect");
            errors = errors + 1;
        end

        write_char(12'hfff, 8'h01);
        timeout = 0;
        while (cpu_busy && timeout < 2500) begin
            @(posedge cpu_clk);
            timeout = timeout + 1;
        end
        cpu_addr = 12'd81;
        #1;
        if ((timeout >= 2500) || (cpu_rdata !== 8'h20)) begin
            $display("VGA clear failed or timed out");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: vga_text_tb");
        else
            $display("FAIL: vga_text_tb errors=%0d", errors);
        $finish;
    end
endmodule

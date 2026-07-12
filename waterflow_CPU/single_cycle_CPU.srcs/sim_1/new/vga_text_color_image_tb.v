`timescale 1ns / 1ps

module vga_text_color_image_tb;
    localparam [13:0] TEXT_CLEAR_ADDR  = 14'h0fff;
    localparam [13:0] IMAGE_POS_ADDR   = 14'h1000;
    localparam [13:0] IMAGE_SIZE_ADDR  = 14'h1001;
    localparam [13:0] IMAGE_DATA_ADDR  = 14'h1002;
    localparam [13:0] IMAGE_CLEAR_ADDR = 14'h1003;

    reg cpu_clk = 1'b0;
    reg pix_clk = 1'b0;
    reg rst = 1'b1;
    reg cpu_we = 1'b0;
    reg [13:0] cpu_addr = 14'd0;
    reg [31:0] cpu_wdata = 32'd0;
    reg [3:0] cpu_wstrb = 4'h0;

    wire [31:0] cpu_rdata;
    wire cpu_busy;
    wire [3:0] vga_r;
    wire [3:0] vga_g;
    wire [3:0] vga_b;
    wire hsync;
    wire vsync;

    always #20 cpu_clk = ~cpu_clk;
    initial begin
        #5;
        forever #20 pix_clk = ~pix_clk;
    end

    vga_text dut (
        .cpu_clk(cpu_clk),
        .pix_clk(pix_clk),
        .rst(rst),
        .cpu_we(cpu_we),
        .cpu_addr(cpu_addr),
        .cpu_wdata(cpu_wdata),
        .cpu_wstrb(cpu_wstrb),
        .cpu_rdata(cpu_rdata),
        .cpu_busy(cpu_busy),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .hsync(hsync),
        .vsync(vsync)
    );

    task cpu_write;
        input [13:0] addr;
        input [31:0] data;
        begin
            @(negedge cpu_clk);
            cpu_addr = addr;
            cpu_wdata = data;
            cpu_wstrb = 4'hf;
            cpu_we = 1'b1;
            @(negedge cpu_clk);
            cpu_we = 1'b0;
            cpu_wstrb = 4'h0;
        end
    endtask

    task expect_rgb;
        input [11:0] expected;
        input [255:0] name;
        begin
            if ({vga_r, vga_g, vga_b} !== expected)
                $fatal(1, "%0s: got RGB %03h, expected %03h",
                       name, {vga_r, vga_g, vga_b}, expected);
        end
    endtask

    initial begin
        #100;
        expect_rgb(12'h000, "reset output");

        repeat (4) @(posedge cpu_clk);
        rst = 1'b0;
        wait (cpu_busy == 1'b0);

        // Each cell retains its own character and RGB444 foreground color.
        cpu_write(14'd0, 32'h000f0041); // red A
        cpu_write(14'd1, 32'h0000f042); // green B
        cpu_write(14'd2, 32'h00000f43); // blue C
        if (dut.char_mem[0] !== 20'hf0041)
            $fatal(1, "red character attribute mismatch: %05h", dut.char_mem[0]);
        if (dut.char_mem[1] !== 20'h0f042)
            $fatal(1, "green character attribute mismatch: %05h", dut.char_mem[1]);
        if (dut.char_mem[2] !== 20'h00f43)
            $fatal(1, "blue character attribute mismatch: %05h", dut.char_mem[2]);

        cpu_addr = 14'd0;
        #1;
        if (cpu_rdata !== 32'h000f0041)
            $fatal(1, "character MMIO readback mismatch: %08h", cpu_rdata);

        // A 2x2 stream wraps at width and keeps the physical 640-pixel stride.
        cpu_write(IMAGE_POS_ADDR, 32'h00000000);
        cpu_write(IMAGE_SIZE_ADDR, 32'h00020002);
        cpu_write(IMAGE_DATA_ADDR, 32'h00000123);
        cpu_write(IMAGE_DATA_ADDR, 32'h00000456);
        cpu_write(IMAGE_DATA_ADDR, 32'h00000789);
        cpu_write(IMAGE_DATA_ADDR, 32'h00000abc);
        if (dut.frame_mem[0] !== 12'h123 || dut.frame_mem[1] !== 12'h456 ||
            dut.frame_mem[640] !== 12'h789 || dut.frame_mem[641] !== 12'habc)
            $fatal(1, "2x2 framebuffer stream layout mismatch");

        // Only the first pixel of this 2x2 stream is inside the viewport.
        cpu_write(IMAGE_POS_ADDR, 32'h01df027f);
        cpu_write(IMAGE_SIZE_ADDR, 32'h00020002);
        cpu_write(IMAGE_DATA_ADDR, 32'h00000f00);
        cpu_write(IMAGE_DATA_ADDR, 32'h000000f0);
        cpu_write(IMAGE_DATA_ADDR, 32'h0000000f);
        cpu_write(IMAGE_DATA_ADDR, 32'h00000fff);
        if (dut.frame_mem[307199] !== 12'hf00)
            $fatal(1, "bottom-right clipping mismatch: %03h",
                   dut.frame_mem[307199]);

        // Fill the background blue while preserving all character attributes.
        cpu_write(IMAGE_CLEAR_ADDR, 32'h0000000f);
        wait (cpu_busy == 1'b1);
        wait (cpu_busy == 1'b0);
        if (dut.frame_mem[0] !== 12'h00f ||
            dut.frame_mem[307199] !== 12'h00f)
            $fatal(1, "framebuffer clear did not cover the full screen");
        if (dut.char_mem[0] !== 20'hf0041)
            $fatal(1, "image clear changed the text layer");

        // Spaces expose the framebuffer; glyph pixels use each cell's color.
        wait (dut.image_ready_sync[1] && dut.text_ready_sync[1]);
        wait (dut.active_q && dut.char_attr_q[7:0] == 8'h41 && !dut.glyph);
        #1;
        expect_rgb(12'h00f, "transparent text background");
        wait (dut.active_q && dut.char_attr_q[7:0] == 8'h41 && dut.glyph);
        #1;
        expect_rgb(12'hf00, "red A glyph");
        wait (dut.active_q && dut.char_attr_q[7:0] == 8'h42 && dut.glyph);
        #1;
        expect_rgb(12'h0f0, "green B glyph");
        wait (dut.active_q && dut.char_attr_q[7:0] == 8'h43 && dut.glyph);
        #1;
        expect_rgb(12'h00f, "blue C glyph");

        cpu_write(TEXT_CLEAR_ADDR, 32'h00000001);
        wait (cpu_busy == 1'b1);
        wait (cpu_busy == 1'b0);
        if (dut.char_mem[0] !== 20'hfff20 ||
            dut.char_mem[2399] !== 20'hfff20)
            $fatal(1, "text clear did not restore blank white attributes");

        $display("PASS: RGB444 image stream and per-cell colored text");
        $finish;
    end

    initial begin
        #100000000;
        $fatal(1, "VGA color/image simulation timed out");
    end
endmodule

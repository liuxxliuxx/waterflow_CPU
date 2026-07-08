module vga_text(
    input  wire        cpu_clk,
    input  wire        pix_clk,
    input  wire        rst,
    input  wire        cpu_we,
    input  wire [11:0] cpu_addr,
    input  wire [7:0]  cpu_wdata,
    output wire [7:0]  cpu_rdata,
    output wire        cpu_busy,
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b,
    output wire        hsync,
    output wire        vsync
);
    reg [9:0] hcnt;
    reg [9:0] vcnt;
    (* ASYNC_REG = "TRUE" *) reg [1:0] pix_rst_sync;
    reg [7:0] char_mem [0:2399];
    reg clear_busy;
    reg [11:0] clear_addr;
    integer i;
    wire active = (hcnt < 10'd640) && (vcnt < 10'd480);
    wire [6:0] char_x = hcnt[9:3];
    wire [4:0] char_y = vcnt[8:4];
    wire [11:0] row_base = {char_y, 6'b0} + {char_y, 4'b0};
    wire [11:0] char_index = row_base + {5'b0, char_x};
    wire pix_addr_valid = active && (char_index < 12'd2400);
    wire cpu_addr_valid = (cpu_addr < 12'd2400);
    wire cpu_clear_addr = (cpu_addr == 12'hfff);
    wire cpu_frame_addr = (cpu_addr == 12'hffe);
    reg frame_busy;
    reg [11:0] frame_addr;
    reg [6:0] frame_col;
    reg [4:0] frame_row;
    reg [7:0] frame_char;
    reg frame_write;
    wire [7:0] ch = pix_addr_valid ? char_mem[char_index] : 8'h20;
    wire [7:0] glyph_row;
    font_rom u_font(.code(ch), .row(vcnt[3:0]), .dots(glyph_row));
    wire glyph = pix_addr_valid && glyph_row[3'd7 - hcnt[2:0]];
    assign hsync = ~((hcnt >= 10'd656) && (hcnt < 10'd752));
    assign vsync = ~((vcnt >= 10'd490) && (vcnt < 10'd492));
    assign cpu_busy = clear_busy || frame_busy;
    assign cpu_rdata = cpu_clear_addr ? {7'h0, clear_busy} : (cpu_addr_valid ? char_mem[cpu_addr] : 8'h00);

    always @(*) begin
        frame_write = 1'b0;
        frame_char = 8'h20;
        if ((frame_row == 5'd3) && (frame_col == 7'd29)) begin
            frame_write = 1'b1;
            frame_char = 8'h2b;
        end else if ((frame_row == 5'd3) && (frame_col > 7'd29) && (frame_col < 7'd50)) begin
            frame_write = 1'b1;
            frame_char = 8'h2d;
        end else if ((frame_row == 5'd3) && (frame_col == 7'd50)) begin
            frame_write = 1'b1;
            frame_char = 8'h2b;
        end else if ((frame_row > 5'd3) && (frame_row < 5'd24) && (frame_col == 7'd29)) begin
            frame_write = 1'b1;
            frame_char = 8'h7c;
        end else if ((frame_row > 5'd3) && (frame_row < 5'd24) && (frame_col > 7'd29) && (frame_col < 7'd50)) begin
            frame_write = 1'b1;
            frame_char = 8'h20;
        end else if ((frame_row > 5'd3) && (frame_row < 5'd24) && (frame_col == 7'd50)) begin
            frame_write = 1'b1;
            frame_char = 8'h7c;
        end else if ((frame_row == 5'd24) && (frame_col == 7'd29)) begin
            frame_write = 1'b1;
            frame_char = 8'h2b;
        end else if ((frame_row == 5'd24) && (frame_col > 7'd29) && (frame_col < 7'd50)) begin
            frame_write = 1'b1;
            frame_char = 8'h2d;
        end else if ((frame_row == 5'd24) && (frame_col == 7'd50)) begin
            frame_write = 1'b1;
            frame_char = 8'h2b;
        end
    end

    initial begin
        pix_rst_sync = 2'b11;
        clear_busy = 1'b0;
        clear_addr = 12'd0;
        frame_busy = 1'b0;
        frame_addr = 12'd0;
        frame_col = 7'd0;
        frame_row = 5'd0;
        for (i = 0; i < 2400; i = i + 1) char_mem[i] = 8'h20;
    end

    always @(posedge cpu_clk) begin
        if (rst) begin
            clear_busy <= 1'b0;
            clear_addr <= 12'd0;
            frame_busy <= 1'b0;
            frame_addr <= 12'd0;
            frame_col <= 7'd0;
            frame_row <= 5'd0;
        end else if (clear_busy) begin
            char_mem[clear_addr] <= 8'h20;
            if (clear_addr == 12'd2399) begin
                clear_busy <= 1'b0;
                clear_addr <= 12'd0;
            end else begin
                clear_addr <= clear_addr + 12'd1;
            end
        end else if (frame_busy) begin
            if (frame_write) char_mem[frame_addr] <= frame_char;
            if (frame_addr == 12'd2399) begin
                frame_busy <= 1'b0;
                frame_addr <= 12'd0;
                frame_col <= 7'd0;
                frame_row <= 5'd0;
            end else begin
                frame_addr <= frame_addr + 12'd1;
                if (frame_col == 7'd79) begin
                    frame_col <= 7'd0;
                    frame_row <= frame_row + 5'd1;
                end else begin
                    frame_col <= frame_col + 7'd1;
                end
            end
        end else if (cpu_we && cpu_clear_addr) begin
            clear_busy <= 1'b1;
            clear_addr <= 12'd0;
        end else if (cpu_we && cpu_frame_addr) begin
            frame_busy <= 1'b1;
            frame_addr <= 12'd0;
            frame_col <= 7'd0;
            frame_row <= 5'd0;
        end else if (cpu_we && cpu_addr_valid) begin
            char_mem[cpu_addr] <= cpu_wdata;
        end
    end

    always @(posedge pix_clk) begin
        pix_rst_sync <= {pix_rst_sync[0], rst};
    end

    always @(posedge pix_clk) begin
        if (pix_rst_sync[1]) begin
            hcnt <= 10'd0;
            vcnt <= 10'd0;
        end else begin
            if (hcnt == 10'd799) begin
                hcnt <= 10'd0;
                if (vcnt == 10'd524) vcnt <= 10'd0;
                else vcnt <= vcnt + 10'd1;
            end else begin
                hcnt <= hcnt + 10'd1;
            end
        end
    end
    always @(*) begin
        if (active && glyph) begin
            vga_r = 4'hf; vga_g = 4'hf; vga_b = 4'hf;
        end else begin
            vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0;
        end
    end
endmodule

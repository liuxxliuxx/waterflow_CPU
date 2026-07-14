module vga_text(
    input  wire        cpu_clk,
    input  wire        pix_clk,
    input  wire        rst,
    input  wire        cpu_we,
    input  wire [13:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    input  wire [3:0]  cpu_wstrb,
    output wire [31:0] cpu_rdata,
    output wire        cpu_busy,
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b,
    output wire        hsync,
    output wire        vsync
);
    localparam [13:0] TEXT_CLEAR_ADDR  = 14'h0fff;
    localparam [13:0] IMAGE_POS_ADDR   = 14'h1000;
    localparam [13:0] IMAGE_SIZE_ADDR  = 14'h1001;
    localparam [13:0] IMAGE_DATA_ADDR  = 14'h1002;
    localparam [13:0] IMAGE_CLEAR_ADDR = 14'h1003;

    localparam [19:0] BLANK_CHAR = {12'hfff, 8'h20};

    reg [9:0] hcnt;
    reg [9:0] vcnt;
    (* ASYNC_REG = "TRUE" *) reg [1:0] pix_rst_sync;
    (* ASYNC_REG = "TRUE" *) reg [1:0] text_ready_sync;
    (* ASYNC_REG = "TRUE" *) reg [1:0] image_ready_sync;
    (* ram_style = "distributed" *) reg [19:0] char_mem [0:2399];

    (* ram_style = "block" *) reg [11:0] frame_mem [0:307199];

    reg        text_clear_busy;
    reg [11:0] text_clear_addr;
    reg        text_ready;

    reg        image_clear_busy;
    reg [18:0] image_clear_addr;
    reg [11:0] image_clear_color;
    reg        image_ready;

    reg [15:0] image_x;
    reg [15:0] image_y;
    reg [15:0] image_width;
    reg [15:0] image_height;
    reg [15:0] stream_x;
    reg [15:0] stream_y;

    reg [19:0] char_attr_q;
    reg [11:0] frame_pixel_q;
    reg [2:0]  glyph_col_q;
    reg [3:0]  glyph_row_q;
    reg        active_q;
    reg        hsync_q;
    reg        vsync_q;

    wire active = (hcnt < 10'd640) && (vcnt < 10'd480);
    wire hsync_now = ~((hcnt >= 10'd656) && (hcnt < 10'd752));
    wire vsync_now = ~((vcnt >= 10'd490) && (vcnt < 10'd492));

    wire [6:0] char_x = hcnt[9:3];
    wire [4:0] char_y = vcnt[8:4];
    wire [11:0] char_row_base = {char_y, 6'b0} + {char_y, 4'b0};
    wire [11:0] char_index = char_row_base + {5'b0, char_x};
    wire char_pixel_valid = active && (char_index < 12'd2400);

    wire [18:0] vcnt_ext = {9'd0, vcnt};
    wire [18:0] hcnt_ext = {9'd0, hcnt};
    wire [18:0] frame_read_addr =
        (vcnt_ext << 9) + (vcnt_ext << 7) + hcnt_ext;

    wire cpu_char_addr_valid = (cpu_addr < 14'd2400);
    wire cpu_accept_write = cpu_we && !text_clear_busy &&
                            !image_clear_busy;

    wire [16:0] stream_abs_x = {1'b0, image_x} + {1'b0, stream_x};
    wire [16:0] stream_abs_y = {1'b0, image_y} + {1'b0, stream_y};
    wire [25:0] stream_x_ext = {9'd0, stream_abs_x};
    wire [25:0] stream_y_ext = {9'd0, stream_abs_y};
    wire [25:0] stream_linear_addr =
        (stream_y_ext << 9) + (stream_y_ext << 7) + stream_x_ext;
    wire stream_has_pixel = (image_width != 16'd0) &&
                            (stream_y < image_height);
    wire stream_in_bounds = stream_has_pixel &&
                            (stream_abs_x < 17'd640) &&
                            (stream_abs_y < 17'd480);
    wire stream_write_request = cpu_accept_write &&
                                (cpu_addr == IMAGE_DATA_ADDR) &&
                                (|cpu_wstrb[1:0]);

    wire frame_write_enable = image_clear_busy ||
                              (stream_write_request && stream_in_bounds);
    wire [18:0] frame_write_addr = image_clear_busy ?
                                   image_clear_addr :
                                   stream_linear_addr[18:0];
    wire [11:0] frame_write_data = image_clear_busy ?
                                   image_clear_color :
                                   cpu_wdata[11:0];

    wire [7:0] glyph_row;
    wire glyph = active_q && text_ready_sync[1] &&
                 glyph_row[3'd7 - glyph_col_q];
    wire [11:0] background_color = image_ready_sync[1] ?
                                   frame_pixel_q : 12'h000;
    wire [11:0] visible_color = !active_q ? 12'h000 :
                                (glyph ? char_attr_q[19:8] :
                                         background_color);

    font_rom u_font(
        .code(char_attr_q[7:0]),
        .row(glyph_row_q),
        .dots(glyph_row)
    );

    assign hsync = hsync_q;
    assign vsync = vsync_q;
    assign cpu_busy = text_clear_busy || image_clear_busy;

    assign cpu_rdata = cpu_char_addr_valid ?
                       {12'h000, char_mem[cpu_addr]} :
                       (cpu_addr == TEXT_CLEAR_ADDR) ?
                       {31'd0, text_clear_busy} :
                       (cpu_addr == IMAGE_POS_ADDR) ?
                       {image_y, image_x} :
                       (cpu_addr == IMAGE_SIZE_ADDR) ?
                       {image_height, image_width} :
                       (cpu_addr == IMAGE_CLEAR_ADDR) ?
                       {31'd0, image_clear_busy} : 32'h00000000;

    initial begin
        hcnt = 10'd0;
        vcnt = 10'd0;
        pix_rst_sync = 2'b11;
        text_ready_sync = 2'b00;
        image_ready_sync = 2'b00;

        text_clear_busy = 1'b1;
        text_clear_addr = 12'd0;
        text_ready = 1'b0;

        image_clear_busy = 1'b1;
        image_clear_addr = 19'd0;
        image_clear_color = 12'h000;
        image_ready = 1'b0;

        image_x = 16'd0;
        image_y = 16'd0;
        image_width = 16'd0;
        image_height = 16'd0;
        stream_x = 16'd0;
        stream_y = 16'd0;

        char_attr_q = BLANK_CHAR;
        frame_pixel_q = 12'h000;
        glyph_col_q = 3'd0;
        glyph_row_q = 4'd0;
        active_q = 1'b0;
        hsync_q = 1'b1;
        vsync_q = 1'b1;
    end

    always @(posedge cpu_clk) begin
        if (rst) begin
            text_clear_busy <= 1'b1;
            text_clear_addr <= 12'd0;
            text_ready <= 1'b0;
        end else if (text_clear_busy) begin
            char_mem[text_clear_addr] <= BLANK_CHAR;
            if (text_clear_addr == 12'd2399) begin
                text_clear_busy <= 1'b0;
                text_clear_addr <= 12'd0;
                text_ready <= 1'b1;
            end else begin
                text_clear_addr <= text_clear_addr + 12'd1;
            end
        end else if (cpu_accept_write &&
                     (cpu_addr == TEXT_CLEAR_ADDR) && (|cpu_wstrb)) begin
            text_clear_busy <= 1'b1;
            text_clear_addr <= 12'd0;
            text_ready <= 1'b0;
        end else if (cpu_accept_write && cpu_char_addr_valid &&
                     (|cpu_wstrb[2:0])) begin
            char_mem[cpu_addr] <= {
                cpu_wstrb[2] ? cpu_wdata[19:16] :
                               char_mem[cpu_addr][19:16],
                cpu_wstrb[1] ? cpu_wdata[15:8] :
                               char_mem[cpu_addr][15:8],
                cpu_wstrb[0] ? cpu_wdata[7:0] :
                               char_mem[cpu_addr][7:0]
            };
        end
    end

    always @(posedge cpu_clk) begin
        if (frame_write_enable)
            frame_mem[frame_write_addr] <= frame_write_data;
    end

    always @(posedge cpu_clk) begin
        if (rst) begin
            image_clear_busy <= 1'b1;
            image_clear_addr <= 19'd0;
            image_clear_color <= 12'h000;
            image_ready <= 1'b0;
            image_x <= 16'd0;
            image_y <= 16'd0;
            image_width <= 16'd0;
            image_height <= 16'd0;
            stream_x <= 16'd0;
            stream_y <= 16'd0;
        end else if (image_clear_busy) begin
            if (image_clear_addr == 19'd307199) begin
                image_clear_busy <= 1'b0;
                image_clear_addr <= 19'd0;
                image_ready <= 1'b1;
            end else begin
                image_clear_addr <= image_clear_addr + 19'd1;
            end
        end else if (cpu_accept_write) begin
            if ((cpu_addr == IMAGE_POS_ADDR) && (|cpu_wstrb)) begin
                if (cpu_wstrb[0]) image_x[7:0] <= cpu_wdata[7:0];
                if (cpu_wstrb[1]) image_x[15:8] <= cpu_wdata[15:8];
                if (cpu_wstrb[2]) image_y[7:0] <= cpu_wdata[23:16];
                if (cpu_wstrb[3]) image_y[15:8] <= cpu_wdata[31:24];
            end

            if ((cpu_addr == IMAGE_SIZE_ADDR) && (|cpu_wstrb)) begin
                if (cpu_wstrb[0]) image_width[7:0] <= cpu_wdata[7:0];
                if (cpu_wstrb[1]) image_width[15:8] <= cpu_wdata[15:8];
                if (cpu_wstrb[2]) image_height[7:0] <= cpu_wdata[23:16];
                if (cpu_wstrb[3]) image_height[15:8] <= cpu_wdata[31:24];
                stream_x <= 16'd0;
                stream_y <= 16'd0;
            end else if (stream_write_request && stream_has_pixel) begin
                if (stream_x == (image_width - 16'd1)) begin
                    stream_x <= 16'd0;
                    stream_y <= stream_y + 16'd1;
                end else begin
                    stream_x <= stream_x + 16'd1;
                end
            end

            if ((cpu_addr == IMAGE_CLEAR_ADDR) && (|cpu_wstrb[1:0])) begin
                image_clear_busy <= 1'b1;
                image_clear_addr <= 19'd0;
                image_clear_color <= cpu_wdata[11:0];
                image_ready <= 1'b0;
            end
        end
    end

    always @(posedge pix_clk) begin
        pix_rst_sync <= {pix_rst_sync[0], rst};
        text_ready_sync <= {text_ready_sync[0], text_ready};
        image_ready_sync <= {image_ready_sync[0], image_ready};
    end

    always @(posedge pix_clk) begin
        if (pix_rst_sync[1]) begin
            hcnt <= 10'd0;
            vcnt <= 10'd0;
            char_attr_q <= BLANK_CHAR;
            frame_pixel_q <= 12'h000;
            glyph_col_q <= 3'd0;
            glyph_row_q <= 4'd0;
            active_q <= 1'b0;
            hsync_q <= 1'b1;
            vsync_q <= 1'b1;
        end else begin
            active_q <= active;
            hsync_q <= hsync_now;
            vsync_q <= vsync_now;
            glyph_col_q <= hcnt[2:0];
            glyph_row_q <= vcnt[3:0];

            if (char_pixel_valid)
                char_attr_q <= char_mem[char_index];
            else
                char_attr_q <= BLANK_CHAR;

            if (active)
                frame_pixel_q <= frame_mem[frame_read_addr];
            else
                frame_pixel_q <= 12'h000;

            if (hcnt == 10'd799) begin
                hcnt <= 10'd0;
                if (vcnt == 10'd524)
                    vcnt <= 10'd0;
                else
                    vcnt <= vcnt + 10'd1;
            end else begin
                hcnt <= hcnt + 10'd1;
            end
        end
    end

    always @(*) begin
        vga_r = visible_color[11:8];
        vga_g = visible_color[7:4];
        vga_b = visible_color[3:0];
    end
endmodule

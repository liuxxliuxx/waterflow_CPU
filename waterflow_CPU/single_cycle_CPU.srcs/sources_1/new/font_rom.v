// 8x16 ASCII font ROM.  Maps an ASCII code (0x00..0x7f) and a row index
// (0..15) to an 8-bit pixel row where bit 7 = leftmost pixel.
// Glyphs 0x00..0x1f render as blank; 0x20..0x7f use font_rom_data.vh.
// Inferred as a single-port ROM (combinational read) suitable for BRAM/LUT.
module font_rom(
    input  wire [7:0] code,
    input  wire [3:0] row,
    output wire [7:0] dots
);
    // 8x16 ASCII font data (96 glyphs x 16 rows).  Included inside the module
    // so the localparam/reg/initial land in module scope.
`include "font_rom_data.vh"
    // Fold unknown codes to blank.  Index = code - FONT_FIRST when in range.
    wire in_range = (code >= FONT_FIRST) && (code <= FONT_LAST);
    wire [6:0] idx = in_range ? (code - FONT_FIRST) : 7'd0;
    // Blank rows beyond FONT_ROWS-1 (should not happen, defensive).
    wire row_ok = (row < FONT_ROWS);
    reg [7:0] dots_r;
    always @(*) begin
        if (!row_ok)            dots_r = 8'h00;
        else if (!in_range)     dots_r = 8'h00;
        else                    dots_r = font_data[idx][(15 - row)*8 +: 8];
    end
    assign dots = dots_r;
endmodule

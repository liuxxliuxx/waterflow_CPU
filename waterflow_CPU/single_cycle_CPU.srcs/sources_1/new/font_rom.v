
module font_rom(
    input  wire [7:0] code,
    input  wire [3:0] row,
    output wire [7:0] dots
);
`include "font_rom_data.vh"
    wire in_range = (code >= FONT_FIRST) && (code <= FONT_LAST);
    wire [6:0] idx = in_range ? (code - FONT_FIRST) : 7'd0;
    wire row_ok = (row < FONT_ROWS);
    reg [7:0] dots_r;
    always @(*) begin
        if (!row_ok)            dots_r = 8'h00;
        else if (!in_range)     dots_r = 8'h00;
        else                    dots_r = font_data[idx][(15 - row)*8 +: 8];
    end
    assign dots = dots_r;
endmodule

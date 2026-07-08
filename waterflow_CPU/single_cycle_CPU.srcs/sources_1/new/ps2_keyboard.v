module ps2_keyboard(
    input  wire       clk,
    input  wire       rst,
    input  wire       ps2_clk,
    input  wire       ps2_dat,
    input  wire       rd_en,
    output wire [7:0] rd_data,
    output wire       empty,
    output wire       full,
    output wire       overflow,
    output wire       frame_error,
    output reg        shift_down,
    output reg        caps_lock
);
    wire byte_valid;
    wire [7:0] byte_data;
    reg break_seen;
    reg ext_seen;
    reg wr_en;
    reg [7:0] wr_data;

    ps2_rx u_rx(.clk(clk), .rst(rst), .ps2_clk(ps2_clk), .ps2_dat(ps2_dat),
        .byte_valid(byte_valid), .byte_data(byte_data), .frame_error(frame_error));

    sync_fifo #(.WIDTH(8), .DEPTH_BITS(5)) u_ascii_fifo(.clk(clk), .rst(rst),
        .wr_en(wr_en), .wr_data(wr_data), .rd_en(rd_en),
        .rd_data(rd_data), .empty(empty), .full(full), .overflow(overflow));

    function [7:0] letter;
        input [7:0] scan;
        input       upper;
        begin
            case (scan)
                8'h1c: letter = upper ? "A" : "a";
                8'h32: letter = upper ? "B" : "b";
                8'h21: letter = upper ? "C" : "c";
                8'h23: letter = upper ? "D" : "d";
                8'h24: letter = upper ? "E" : "e";
                8'h2b: letter = upper ? "F" : "f";
                8'h34: letter = upper ? "G" : "g";
                8'h33: letter = upper ? "H" : "h";
                8'h43: letter = upper ? "I" : "i";
                8'h3b: letter = upper ? "J" : "j";
                8'h42: letter = upper ? "K" : "k";
                8'h4b: letter = upper ? "L" : "l";
                8'h3a: letter = upper ? "M" : "m";
                8'h31: letter = upper ? "N" : "n";
                8'h44: letter = upper ? "O" : "o";
                8'h4d: letter = upper ? "P" : "p";
                8'h15: letter = upper ? "Q" : "q";
                8'h2d: letter = upper ? "R" : "r";
                8'h1b: letter = upper ? "S" : "s";
                8'h2c: letter = upper ? "T" : "t";
                8'h3c: letter = upper ? "U" : "u";
                8'h2a: letter = upper ? "V" : "v";
                8'h1d: letter = upper ? "W" : "w";
                8'h22: letter = upper ? "X" : "x";
                8'h35: letter = upper ? "Y" : "y";
                8'h1a: letter = upper ? "Z" : "z";
                default: letter = 8'h00;
            endcase
        end
    endfunction

    function [7:0] key_ascii;
        input [7:0] scan;
        input       shift;
        input       caps;
        reg         upper;
        begin
            upper = shift ^ caps;
            key_ascii = letter(scan, upper);
            if (key_ascii == 8'h00) begin
                case (scan)
                    8'h16: key_ascii = shift ? "!" : "1";
                    8'h1e: key_ascii = shift ? "@" : "2";
                    8'h26: key_ascii = shift ? "#" : "3";
                    8'h25: key_ascii = shift ? "$" : "4";
                    8'h2e: key_ascii = shift ? "%" : "5";
                    8'h36: key_ascii = shift ? "^" : "6";
                    8'h3d: key_ascii = shift ? "&" : "7";
                    8'h3e: key_ascii = shift ? "*" : "8";
                    8'h46: key_ascii = shift ? "(" : "9";
                    8'h45: key_ascii = shift ? ")" : "0";
                    8'h4e: key_ascii = shift ? "_" : "-";
                    8'h55: key_ascii = shift ? "+" : "=";
                    8'h54: key_ascii = shift ? "{" : "[";
                    8'h5b: key_ascii = shift ? "}" : "]";
                    8'h4c: key_ascii = shift ? ":" : ";";
                    8'h52: key_ascii = shift ? 8'h22 : "'";
                    8'h0e: key_ascii = shift ? "~" : "`";
                    8'h41: key_ascii = shift ? "<" : ",";
                    8'h49: key_ascii = shift ? ">" : ".";
                    8'h4a: key_ascii = shift ? "?" : "/";
                    8'h5d: key_ascii = shift ? "|" : "\\";
                    8'h29: key_ascii = " ";
                    8'h5a: key_ascii = 8'h0d;
                    8'h66: key_ascii = 8'h08;
                    8'h0d: key_ascii = 8'h09;
                    8'h76: key_ascii = 8'h1b;
                    default: key_ascii = 8'h00;
                endcase
            end
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            break_seen <= 1'b0;
            ext_seen <= 1'b0;
            shift_down <= 1'b0;
            caps_lock <= 1'b0;
            wr_en <= 1'b0;
            wr_data <= 8'h0;
        end else begin
            wr_en <= 1'b0;
            if (byte_valid) begin
                if (byte_data == 8'hf0) begin
                    break_seen <= 1'b1;
                end else if (byte_data == 8'he0) begin
                    ext_seen <= 1'b1;
                end else begin
                    if ((byte_data == 8'h12) || (byte_data == 8'h59)) begin
                        shift_down <= !break_seen;
                    end else if (!break_seen && !ext_seen && (byte_data == 8'h58)) begin
                        caps_lock <= !caps_lock;
                    end else if (!break_seen && !ext_seen && (key_ascii(byte_data, shift_down, caps_lock) != 8'h00)) begin
                        wr_en <= 1'b1;
                        wr_data <= key_ascii(byte_data, shift_down, caps_lock);
                    end
                    break_seen <= 1'b0;
                    ext_seen <= 1'b0;
                end
            end
        end
    end
endmodule

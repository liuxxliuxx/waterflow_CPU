module sevenseg_scan #(
    parameter integer SCAN_DIV = 3125
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] pattern_lo,
    input  wire [31:0] pattern_hi,
    input  wire [7:0]  enable,
    output reg  [7:0]  seg_csn,
    output reg  [7:0]  seg
);
    reg [31:0] scan_count;
    reg [2:0] digit_index;
    reg blank_cycle;

    function [7:0] selected_pattern;
        input [2:0] index;
        begin
            case (index)
                3'd0: selected_pattern = pattern_lo[7:0];
                3'd1: selected_pattern = pattern_lo[15:8];
                3'd2: selected_pattern = pattern_lo[23:16];
                3'd3: selected_pattern = pattern_lo[31:24];
                3'd4: selected_pattern = pattern_hi[7:0];
                3'd5: selected_pattern = pattern_hi[15:8];
                3'd6: selected_pattern = pattern_hi[23:16];
                default: selected_pattern = pattern_hi[31:24];
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            scan_count <= 32'd0;
            digit_index <= 3'd0;
            blank_cycle <= 1'b1;
            seg_csn <= 8'hff;
            seg <= 8'h00;
        end else if (blank_cycle) begin
            blank_cycle <= 1'b0;
            if (enable[digit_index]) begin
                seg <= selected_pattern(digit_index);
                seg_csn <= ~(8'b0000_0001 << digit_index);
            end else begin
                seg <= 8'h00;
                seg_csn <= 8'hff;
            end
        end else if (scan_count == SCAN_DIV - 1) begin
            scan_count <= 32'd0;
            digit_index <= digit_index + 3'd1;
            blank_cycle <= 1'b1;
            seg_csn <= 8'hff;
            seg <= 8'h00;
        end else begin
            scan_count <= scan_count + 32'd1;
        end
    end
endmodule

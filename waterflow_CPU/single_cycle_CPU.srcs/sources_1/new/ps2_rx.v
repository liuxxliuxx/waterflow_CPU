module ps2_rx(
    input  wire clk,
    input  wire rst,
    input  wire ps2_clk,
    input  wire ps2_dat,
    output reg        byte_valid,
    output reg [7:0]  byte_data,
    output reg        frame_error
);
    reg [2:0] clk_sync;
    reg [2:0] dat_sync;
    reg [3:0] bit_count;
    reg [10:0] shift;
    wire falling = clk_sync[2:1] == 2'b10;
    always @(posedge clk) begin
        if (rst) begin
            clk_sync <= 3'b111;
            dat_sync <= 3'b111;
            bit_count <= 4'd0;
            shift <= 11'h0;
            byte_valid <= 1'b0;
            byte_data <= 8'h00;
            frame_error <= 1'b0;
        end else begin
            clk_sync <= {clk_sync[1:0], ps2_clk};
            dat_sync <= {dat_sync[1:0], ps2_dat};
            byte_valid <= 1'b0;
            if (falling) begin
                shift <= {dat_sync[2], shift[10:1]};
                if (bit_count == 4'd10) begin
                    bit_count <= 4'd0;
                    byte_data <= shift[9:2];
                    byte_valid <= 1'b1;
                    frame_error <= shift[1] | !dat_sync[2];
                end else begin
                    bit_count <= bit_count + 4'd1;
                end
            end
        end
    end
endmodule

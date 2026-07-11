module ps2_rx #(
    parameter integer FRAME_TIMEOUT_CYCLES = 50000
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       ps2_clk,
    input  wire       ps2_dat,
    output reg        byte_valid,
    output reg [7:0]  byte_data,
    output reg        frame_error
);
    (* ASYNC_REG = "TRUE" *) reg [2:0] clk_sync;
    (* ASYNC_REG = "TRUE" *) reg [2:0] dat_sync;
    reg [3:0] bit_count;
    reg [7:0] data_shift;
    reg parity_bit;
    reg [31:0] timeout_count;

    wire falling = (clk_sync[2:1] == 2'b10);
    wire sampled_data = dat_sync[2];

    always @(posedge clk) begin
        if (rst) begin
            clk_sync <= 3'b111;
            dat_sync <= 3'b111;
            bit_count <= 4'd0;
            data_shift <= 8'h00;
            parity_bit <= 1'b0;
            timeout_count <= 32'd0;
            byte_valid <= 1'b0;
            byte_data <= 8'h00;
            frame_error <= 1'b0;
        end else begin
            clk_sync <= {clk_sync[1:0], ps2_clk};
            dat_sync <= {dat_sync[1:0], ps2_dat};
            byte_valid <= 1'b0;
            frame_error <= 1'b0;

            if (falling) begin
                timeout_count <= 32'd0;
                case (bit_count)
                    4'd0: begin
                        if (!sampled_data)
                            bit_count <= 4'd1;
                        else
                            frame_error <= 1'b1;
                    end
                    4'd1, 4'd2, 4'd3, 4'd4,
                    4'd5, 4'd6, 4'd7, 4'd8: begin
                        data_shift[bit_count - 4'd1] <= sampled_data;
                        bit_count <= bit_count + 4'd1;
                    end
                    4'd9: begin
                        parity_bit <= sampled_data;
                        bit_count <= 4'd10;
                    end
                    4'd10: begin
                        bit_count <= 4'd0;
                        if (sampled_data && ((^data_shift) ^ parity_bit)) begin
                            byte_data <= data_shift;
                            byte_valid <= 1'b1;
                        end else begin
                            frame_error <= 1'b1;
                        end
                    end
                    default: begin
                        bit_count <= 4'd0;
                        frame_error <= 1'b1;
                    end
                endcase
            end else if (bit_count != 4'd0) begin
                if (timeout_count == FRAME_TIMEOUT_CYCLES - 1) begin
                    bit_count <= 4'd0;
                    timeout_count <= 32'd0;
                    frame_error <= 1'b1;
                end else begin
                    timeout_count <= timeout_count + 32'd1;
                end
            end else begin
                timeout_count <= 32'd0;
            end
        end
    end
endmodule

module uart_tx_simple #(
    parameter integer CLK_HZ = 25000000,
    parameter integer BAUD = 115200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       send,
    input  wire [7:0] data,
    output reg        tx,
    output wire       busy
);
    localparam integer BAUD_DIV = (CLK_HZ + (BAUD / 2)) / BAUD;

    reg [31:0] baud_count;
    reg [3:0] bit_index;
    reg [7:0] data_latched;
    reg active;

    assign busy = active;

    always @(posedge clk) begin
        if (rst) begin
            tx <= 1'b1;
            baud_count <= 32'd0;
            bit_index <= 4'd0;
            data_latched <= 8'h00;
            active <= 1'b0;
        end else if (send && !active) begin
            tx <= 1'b0;
            baud_count <= 32'd0;
            bit_index <= 4'd0;
            data_latched <= data;
            active <= 1'b1;
        end else if (active) begin
            if (baud_count == BAUD_DIV - 1) begin
                baud_count <= 32'd0;
                if (bit_index < 4'd8) begin
                    tx <= data_latched[bit_index];
                    bit_index <= bit_index + 4'd1;
                end else if (bit_index == 4'd8) begin
                    tx <= 1'b1;
                    bit_index <= 4'd9;
                end else begin
                    tx <= 1'b1;
                    active <= 1'b0;
                end
            end else begin
                baud_count <= baud_count + 32'd1;
            end
        end
    end
endmodule

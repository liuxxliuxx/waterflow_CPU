module uart_tx_simple #(
    parameter CLK_HZ = 100000000,
    parameter BAUD = 115200
)(
    input  wire clk,
    input  wire rst,
    input  wire send,
    input  wire [7:0] data,
    output reg  tx,
    output wire busy
);
    localparam integer BAUD_DIV = CLK_HZ / BAUD;
    reg [15:0] baud_cnt;
    reg [3:0] bit_cnt;
    reg [9:0] shifter;
    reg active;
    assign busy = active;
    always @(posedge clk) begin
        if (rst) begin
            tx <= 1'b1; baud_cnt <= 16'd0; bit_cnt <= 4'd0; shifter <= 10'h3ff; active <= 1'b0;
        end else begin
            if (send && !active) begin
                active <= 1'b1;
                shifter <= {1'b1, data, 1'b0};
                baud_cnt <= 16'd0;
                bit_cnt <= 4'd0;
            end else if (active) begin
                if (baud_cnt == BAUD_DIV[15:0]) begin
                    baud_cnt <= 16'd0;
                    tx <= shifter[0];
                    shifter <= {1'b1, shifter[9:1]};
                    bit_cnt <= bit_cnt + 4'd1;
                    if (bit_cnt == 4'd10) active <= 1'b0;
                end else baud_cnt <= baud_cnt + 16'd1;
            end
        end
    end
endmodule

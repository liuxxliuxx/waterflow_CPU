module sync_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH_BITS = 4
)(
    input  wire clk,
    input  wire rst,
    input  wire wr_en,
    input  wire [WIDTH-1:0] wr_data,
    input  wire rd_en,
    output wire [WIDTH-1:0] rd_data,
    output wire empty,
    output wire full,
    output reg  overflow
);
    localparam DEPTH = (1 << DEPTH_BITS);
    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [DEPTH_BITS:0] wptr, rptr;
    assign empty = (wptr == rptr);
    assign full = (wptr[DEPTH_BITS] != rptr[DEPTH_BITS]) && (wptr[DEPTH_BITS-1:0] == rptr[DEPTH_BITS-1:0]);
    assign rd_data = mem[rptr[DEPTH_BITS-1:0]];
    always @(posedge clk) begin
        if (rst) begin
            wptr <= 0; rptr <= 0; overflow <= 1'b0;
        end else begin
            if (wr_en) begin
                if (!full) begin
                    mem[wptr[DEPTH_BITS-1:0]] <= wr_data;
                    wptr <= wptr + 1'b1;
                end else overflow <= 1'b1;
            end
            if (rd_en && !empty) rptr <= rptr + 1'b1;
        end
    end
endmodule

module ps2_keyboard #(
    parameter integer DEPTH_BITS = 5
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       ps2_clk,
    input  wire       ps2_dat,
    input  wire       rd_en,
    input  wire       clear_errors,
    output wire [7:0] rd_data,
    output wire       empty,
    output wire       full,
    output reg        overflow,
    output reg        frame_error
);
    localparam integer DEPTH = (1 << DEPTH_BITS);

    wire rx_valid;
    wire [7:0] rx_data;
    wire rx_frame_error;
    reg [7:0] fifo [0:DEPTH-1];
    reg [DEPTH_BITS:0] write_ptr;
    reg [DEPTH_BITS:0] read_ptr;

    assign empty = (write_ptr == read_ptr);
    assign full = (write_ptr[DEPTH_BITS] != read_ptr[DEPTH_BITS]) &&
                  (write_ptr[DEPTH_BITS-1:0] == read_ptr[DEPTH_BITS-1:0]);
    assign rd_data = empty ? 8'h00 : fifo[read_ptr[DEPTH_BITS-1:0]];

    ps2_rx u_rx(
        .clk(clk),
        .rst(rst),
        .ps2_clk(ps2_clk),
        .ps2_dat(ps2_dat),
        .byte_valid(rx_valid),
        .byte_data(rx_data),
        .frame_error(rx_frame_error)
    );

    always @(posedge clk) begin
        if (rst) begin
            write_ptr <= {(DEPTH_BITS + 1){1'b0}};
            read_ptr <= {(DEPTH_BITS + 1){1'b0}};
            overflow <= 1'b0;
            frame_error <= 1'b0;
        end else begin
            if (clear_errors) begin
                overflow <= 1'b0;
                frame_error <= 1'b0;
            end

            if (rx_frame_error)
                frame_error <= 1'b1;

            if (rx_valid) begin
                if (!full || (rd_en && !empty)) begin
                    fifo[write_ptr[DEPTH_BITS-1:0]] <= rx_data;
                    write_ptr <= write_ptr + {{DEPTH_BITS{1'b0}}, 1'b1};
                end else begin
                    overflow <= 1'b1;
                end
            end

            if (rd_en && !empty)
                read_ptr <= read_ptr + {{DEPTH_BITS{1'b0}}, 1'b1};
        end
    end
endmodule

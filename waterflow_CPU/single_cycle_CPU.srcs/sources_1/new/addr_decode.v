`timescale 1ns / 1ps
module addr_decode(
    input wire [31:0] addr,
    output reg [2:0] region,
    output reg [31:0] paddr,
    output reg cached,
    output reg err
);
    localparam LOCAL = 3'd0;
    localparam DDR = 3'd1;
    localparam MMIO = 3'd2;
    localparam NAND = 3'd3;
    localparam BAD = 3'd7;

    always @(*) begin
        paddr = addr;
        cached = 1'b0;
        err = 1'b0;
        if (addr[31:16] == 16'h1c00) begin
            region = LOCAL;
        end else if (addr[31:28] == 4'h8) begin
            region = DDR;
            paddr = {4'h0, addr[27:0]};
            cached = 1'b1;
        end else if (addr[31:28] == 4'ha) begin
            region = DDR;
            paddr = {4'h0, addr[27:0]};
        end else if (addr[31:16] == 16'h1fd0) begin
            region = NAND;
        end else if (addr[31:16] >= 16'h1fe0 && addr[31:16] <= 16'h1fef) begin
            region = MMIO;
        end else begin
            region = BAD;
            err = 1'b1;
        end
    end
endmodule

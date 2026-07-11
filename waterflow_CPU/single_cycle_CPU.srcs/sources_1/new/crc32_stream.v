`timescale 1ns / 1ps

module crc32_stream(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        clear,
    input  wire        data_valid,
    input  wire [31:0] data,
    input  wire [3:0]  data_wstrb,
    output reg  [31:0] value
);
    function [31:0] update_byte;
        input [31:0] crc_in;
        input [7:0] data_in;
        integer bit_index;
        reg [31:0] crc;
        begin
            crc = crc_in ^ {24'd0, data_in};
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                if (crc[0])
                    crc = (crc >> 1) ^ 32'hedb8_8320;
                else
                    crc = crc >> 1;
            end
            update_byte = crc;
        end
    endfunction

    reg [31:0] next_value;

    always @(*) begin
        next_value = value;
        if (data_wstrb[0])
            next_value = update_byte(next_value, data[7:0]);
        if (data_wstrb[1])
            next_value = update_byte(next_value, data[15:8]);
        if (data_wstrb[2])
            next_value = update_byte(next_value, data[23:16]);
        if (data_wstrb[3])
            next_value = update_byte(next_value, data[31:24]);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            value <= 32'hffff_ffff;
        else if (clear)
            value <= 32'hffff_ffff;
        else if (data_valid)
            value <= next_value;
    end
endmodule

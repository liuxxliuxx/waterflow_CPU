`timescale 1ns / 1ps


module lcd_cpu_display(
    input         clk,
    input         resetn,
    output        lcd_rst,
    output        lcd_cs,
    output        lcd_rs,
    output        lcd_wr,
    output        lcd_rd,
    inout  [15:0] lcd_data_io,
    output        lcd_bl_ctr,
    inout         ct_int,
    inout         ct_sda,
    output        ct_scl,
    output        ct_rstn,
    output [4:0]  test_addr,
    input  [31:0] test_data,
    input  [31:0] test_pc_cur,
    input  [31:0] test_inst
);
    reg         display_valid;
    reg  [39:0] display_name;
    reg  [31:0] display_value;
    wire [5:0]  display_number;
    wire        input_valid;
    wire [31:0] input_value;

    lcd_module lcd_module(
        .clk(clk),
        .resetn(resetn),
        .display_valid(display_valid),
        .display_name(display_name),
        .display_value(display_value),
        .display_number(display_number),
        .input_valid(input_valid),
        .input_value(input_value),
        .lcd_rst(lcd_rst),
        .lcd_cs(lcd_cs),
        .lcd_rs(lcd_rs),
        .lcd_wr(lcd_wr),
        .lcd_rd(lcd_rd),
        .lcd_data_io(lcd_data_io),
        .lcd_bl_ctr(lcd_bl_ctr),
        .ct_int(ct_int),
        .ct_sda(ct_sda),
        .ct_scl(ct_scl),
        .ct_rstn(ct_rstn)
    );

    assign test_addr = display_number[4:0];

    always @(posedge clk) begin
        display_valid <= 1'b0;
        if (display_number > 6'd0 && display_number < 6'd33) begin
            display_valid <= 1'b1;
            display_name[39:16] <= "REG";
            display_name[15:8] <= {4'b0011, 3'b000, test_addr[4]};
            display_name[7:0] <= {4'b0011, test_addr[3:0]};
            display_value <= test_data;
        end
        else begin
            case (display_number)
                6'd33: begin
                    display_valid <= 1'b1;
                    display_name <= "PC   ";
                    display_value <= test_pc_cur;
                end
                6'd34: begin
                    display_valid <= 1'b1;
                    display_name <= "INST ";
                    display_value <= test_inst;
                end
            endcase
        end
    end
endmodule

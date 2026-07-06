module peripheral_bus(
    input         clk,
    input         rst,
    
    input         bus_req,
    input         bus_we,
    input  [31:0] bus_addr,
    input  [31:0] bus_wdata,
    output [31:0] bus_rdata,
    
    input  [31:0] lcd_input,
    output        lcd_wr_en,
    output [31:0] lcd_wr_data
    );
endmodule

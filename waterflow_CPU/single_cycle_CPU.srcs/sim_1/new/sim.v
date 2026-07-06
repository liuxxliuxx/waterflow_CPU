`timescale 1ns / 1ps
module sim;
    reg clk;
    reg rst;
    reg[4:0] test_addr;
    wire[31:0] test_data;
    wire[31:0] pc;
    wire[31:0] inst;
    reg [31:0] ans;
    
    wire[31:0] wr_data;
    wire lcd_wr_en;
    
    wire bus_req;
    wire bus_we;
    wire[31:0] bus_addr;
    wire[31:0] bus_wdata;
    wire[31:0] bus_rdata;
    wire bus_ready;
    
    CPU u_cpu(
        .clk(clk),
        .rst(rst),
        .test_addr(test_addr),
        .test_data(test_data),
        .test_pc_cur(pc),
        .test_inst(inst),
        
        .bus_req(bus_req),
        .bus_we(bus_we),
        .bus_addr(bus_addr),
        .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata),
        .bus_ready(bus_ready)
    );
    
    bus_controller u_bus_ctrl(
        .clk(clk),
        .rst(rst),
        .bus_req(bus_req),
        .bus_we(bus_we),
        .bus_addr(bus_addr),
        .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata),
        .bus_ready(bus_ready),
        .lcd_input(32'd5),
        .lcd_wr_data(wr_data),
        .lcd_wr_en(lcd_wr_en)
    );
    initial begin
        rst = 0;
        clk = 0;
        test_addr = 0;
        #20;
        rst = 1;#5;
    end
    
    always #6 clk = ~clk;
    reg[5:0] i;
    always @(posedge clk or negedge rst) begin
        #5;
        for(i = 5'd0;i <= 5'd31;i = i + 5'd1) begin
            test_addr <= i;
            #1;
        end
    end
    always @(posedge clk or negedge rst) begin
        if(!rst) ans <= 32'd0;
        else if(lcd_wr_en) ans <= wr_data;
    end
endmodule

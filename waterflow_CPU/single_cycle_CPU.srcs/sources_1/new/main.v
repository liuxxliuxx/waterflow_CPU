`timescale 1ns / 1ps
module main(
    input clk,
    input clk_lcd,
    input rst,
    output lcd_rst,
    output lcd_cs,
    output lcd_rs,
    output lcd_wr,
    output lcd_rd,
    inout[15:0] lcd_data_io,
    output lcd_bl_ctr,
    inout ct_int,
    inout ct_sda,
    output ct_scl,
    output ct_rstn
);
    reg         display_valid;
    reg  [39:0] display_name;
    reg  [31:0] display_value;
    
    
    wire [5 :0] display_number;
    wire        input_valid; 
    wire [31:0] input_value;
    
    wire [4:0] test_addr;
    wire [31:0] test_data;
    
    wire[31:0] pc_cur;
    wire[31:0] instr;
    
    reg[31:0]   lcd_input;
    wire[31:0] lcd_wr_data;
    wire       lcd_wr_en;
    
    reg[31:0] wr_data;
    reg[31:0] input_data;
    wire cpu_clk;
    
    wire bus_req;
    wire bus_we;
    wire[31:0] bus_addr;
    wire[31:0] bus_wdata;
    wire[31:0] bus_rdata;
    wire bus_ready;
    
    cpuclk u_cpuclk(.clk_in1(clk_lcd),.clk_out1(cpu_clk));
    
    CPU u_cpu(
        .clk(cpu_clk),
        .rst(rst),
        .test_addr(test_addr),
        .test_data(test_data),
        .test_pc_cur(pc_cur),
        .test_inst(instr),
        
        .bus_req(bus_req),
        .bus_we(bus_we),
        .bus_addr(bus_addr),
        .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata),
        .bus_ready(bus_ready)
    );
    
    bus_controller u_bus_ctrl(
        .clk(cpu_clk),
        .rst(rst),
        .bus_req(bus_req),
        .bus_we(bus_we),
        .bus_addr(bus_addr),
        .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata),
        .bus_ready(bus_ready),
        .lcd_input(lcd_input),
        .lcd_wr_en(lcd_wr_en),
        .lcd_wr_data(lcd_wr_data)
    );
    
    assign test_addr = display_number[4:0] - 4'd1;
    
    

    lcd_module lcd_module(
    clk_lcd,rst,display_valid,
    display_name,display_value,
    display_number,input_valid,
    input_value,lcd_rst,lcd_cs,
    lcd_rs,lcd_wr,lcd_rd,
    lcd_data_io,lcd_bl_ctr,
    ct_int,ct_sda,ct_scl,ct_rstn);
    
    always @(posedge clk_lcd) begin
        if(!rst)begin 
            lcd_input <=32'd0;
            input_data <= 32'd0;
            wr_data <= 32'd0;
        end
        else begin
            if(input_valid) begin
                lcd_input <= input_value;
                input_data <= input_value;
            end
            if(lcd_wr_en) wr_data <= lcd_wr_data;
        end
    end
    
    always @(posedge clk_lcd) begin
        if(display_number > 6'd0 &&display_number < 6'd33) begin
            display_valid <= 1'b1;
            display_name[39:16] <= "REG";
            display_name[15:8] <= {4'b0011,3'b000,test_addr[4]};
            display_name[7:0] <= {4'b0011,test_addr[3:0]};
            display_value <= test_data;
        end
        else begin
        
            case(display_number)
                6'd33: begin
                    display_valid<=1'b1;
                    display_name<="PC   ";
                    display_value<=pc_cur;
                end
                6'd34: begin
                    display_valid<=1'b1;
                    display_name<="INSTR";
                    display_value<=instr;
                end
                6'd35: begin
                    display_valid<=1'b1;
                    display_name<="INPUT";
                    display_value<=input_data;
                end
                6'd36: begin
                    display_valid<=1'b1;
                    display_name<="OUTPT";
                    display_value<=wr_data;
                end
                default: begin
                    display_valid<=1'b0;
                end
            endcase
            
        end
    end
endmodule

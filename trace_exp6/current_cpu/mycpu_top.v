`timescale 1ns / 1ps
module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    
    output wire [3 :0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    input  wire [31:0] inst_sram_rdata,
    output wire [31:0] inst_sram_wdata,

    output wire [3 :0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,

    output wire [31:0] debug_wb_pc,
    output wire [3 :0] debug_wb_rf_we,
    output wire [4 :0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    wire [4 :0] test_addr = 5'd0;
    wire [31:0] test_data;
    wire [31:0] test_pc_cur;
    wire [31:0] test_inst;
    wire [31:0] inst_fetch_addr;

    wire        bus_req;
    wire        bus_we;
    wire [31:0] bus_addr;
    wire [31:0] bus_wdata;
    wire [31:0] bus_rdata;
    wire        bus_ready;
    
    assign inst_sram_wdata = 32'b0;
    assign inst_sram_we    = 4'b0;

    CPU u_cpu(
        .clk(clk),
        .rst(resetn),
        .test_addr(test_addr),
        .test_data(test_data),
        .test_pc_cur(test_pc_cur),
        .test_inst(test_inst),
        .inst_sram_addr(inst_fetch_addr),

        .bus_req(bus_req),
        .bus_we(bus_we),
        .bus_addr(bus_addr),
        .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata),
        .bus_ready(bus_ready),
        .instt(inst_sram_rdata)
    );

    assign inst_sram_en    = resetn;
    assign inst_sram_addr  = inst_fetch_addr;

    assign data_sram_en    = bus_req;
    assign data_sram_we   = bus_we ? 4'hf : 4'h0;
    assign data_sram_addr  = bus_addr;
    assign data_sram_wdata = bus_wdata;

    assign bus_rdata       = data_sram_rdata;
    assign bus_ready       = 1'b1;

    reg [31:0] exmem_pc_shadow;
    reg [31:0] memwb_pc_shadow;

    always @(posedge clk) begin
        if (!resetn) begin
            exmem_pc_shadow <= 32'd0;
            memwb_pc_shadow <= 32'd0;
        end
        else if (!u_cpu.mem_stall) begin
            exmem_pc_shadow <= u_cpu.idex_pc;
            memwb_pc_shadow <= exmem_pc_shadow;
        end
    end

    assign debug_wb_pc       = memwb_pc_shadow;
    assign debug_wb_rf_we   = {4{u_cpu.memwb_valid & u_cpu.memwb_regWr}};
    assign debug_wb_rf_wnum  = u_cpu.memwb_waddr;
    assign debug_wb_rf_wdata = u_cpu.memwb_wdata;
endmodule

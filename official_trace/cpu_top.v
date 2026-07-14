`timescale 1ns / 1ps

// Adapter between the current ready/valid CPU memory ports and the SRAM-style
// interface required by the official Loongson soc_bram verification project.
module cpu_top (
    input  wire        clk,
    input  wire        resetn,

    output wire        inst_sram_en,
    output wire [3:0]  inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,

    output wire        data_sram_en,
    output wire [3:0]  data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,

    output wire [31:0] debug_wb_pc,
    output wire [3:0]  debug_wb_rf_we,
    output wire [4:0]  debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    wire [4:0]  test_addr = 5'd0;
    wire [31:0] test_data;
    wire [31:0] test_pc_cur;
    wire [31:0] test_inst;

    wire        inst_req_valid;
    wire [31:0] inst_req_vaddr;
    reg         inst_resp_valid;

    wire        data_req_valid;
    wire        data_req_we;
    wire [31:0] data_req_vaddr;
    wire [31:0] data_req_wdata;
    wire [3:0]  data_req_wstrb;
    wire [1:0]  data_req_size;
    reg         data_resp_valid;

    CPU u_cpu (
        .clk             (clk),
        .rst             (resetn),
        .test_addr       (test_addr),
        .test_data       (test_data),
        .test_pc_cur     (test_pc_cur),
        .test_inst       (test_inst),

        .inst_req_valid  (inst_req_valid),
        .inst_req_ready  (1'b1),
        .inst_req_vaddr  (inst_req_vaddr),
        .inst_resp_valid (inst_resp_valid),
        .inst_resp_data  (inst_sram_rdata),
        .inst_resp_err   (1'b0),

        .data_req_valid  (data_req_valid),
        .data_req_ready  (1'b1),
        .data_req_we     (data_req_we),
        .data_req_vaddr  (data_req_vaddr),
        .data_req_wdata  (data_req_wdata),
        .data_req_wstrb  (data_req_wstrb),
        .data_req_size   (data_req_size),
        .data_resp_valid (data_resp_valid),
        .data_resp_rdata (data_sram_rdata),
        .data_resp_err   (1'b0),
        .hw_int          (8'b0)
    );

    // The official BRAMs return read data on the cycle after en/address are
    // sampled. Delay each response-valid pulse by the same one clock cycle.
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            inst_resp_valid <= 1'b0;
            data_resp_valid <= 1'b0;
        end else begin
            inst_resp_valid <= inst_req_valid;
            data_resp_valid <= data_req_valid;
        end
    end

    assign inst_sram_en    = inst_req_valid;
    assign inst_sram_we    = 4'b0000;
    assign inst_sram_addr  = inst_req_vaddr;
    assign inst_sram_wdata = 32'b0;

    assign data_sram_en    = data_req_valid;
    assign data_sram_we    = (data_req_valid && data_req_we)
                           ? data_req_wstrb : 4'b0000;
    assign data_sram_addr  = data_req_vaddr;
    assign data_sram_wdata = data_req_wdata;

    // memwb_* is the architectural GPR writeback event. The shadow register
    // captures the matching EX/MEM PC one cycle earlier. Hold the most recent
    // committed PC across pipeline bubbles so the official testbench's
    // periodic status print does not show 0 between writeback events.
    reg [31:0] debug_wb_pc_shadow;
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            debug_wb_pc_shadow <= 32'b0;
        else if (u_cpu.mem_can_commit)
            debug_wb_pc_shadow <= u_cpu.exmem_pc;
    end

    assign debug_wb_pc       = debug_wb_pc_shadow;
    assign debug_wb_rf_we    = {4{u_cpu.memwb_valid && u_cpu.memwb_regWr}};
    assign debug_wb_rf_wnum  = u_cpu.memwb_waddr;
    assign debug_wb_rf_wdata = u_cpu.memwb_wdata;

    // data_req_size is consumed inside CPU/LSU to form wstrb and load data.
    // Keep the signal named here so it remains visible in official waveforms.
    wire [1:0] unused_data_req_size = data_req_size;
endmodule

// The official soc_lite_top instantiates a module named mycpu_top. Keeping the
// compatibility wrapper in this same file avoids modifying official SoC RTL.
module mycpu_top (
    input  wire        clk,
    input  wire        resetn,
    output wire        inst_sram_en,
    output wire [3:0]  inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    output wire        data_sram_en,
    output wire [3:0]  data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    output wire [31:0] debug_wb_pc,
    output wire [3:0]  debug_wb_rf_we,
    output wire [4:0]  debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    cpu_top u_cpu_top (
        .clk(clk),
        .resetn(resetn),
        .inst_sram_en(inst_sram_en),
        .inst_sram_we(inst_sram_we),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_rdata(inst_sram_rdata),
        .data_sram_en(data_sram_en),
        .data_sram_we(data_sram_we),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_rdata(data_sram_rdata),
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );
endmodule

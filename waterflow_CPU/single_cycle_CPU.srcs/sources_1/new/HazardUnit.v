`include "CPU_def.vh"
module HazardUnit(

    //判断load_use
    input            id_valid,
    input      [4:0] id_rs1,
    input      [4:0] id_rs2,
    input            id_src1_used,
    input            id_src2_used,

    //id/ex寄存器内信息
    input            ex_valid,
    input      [4:0] ex_rs1,
    input      [4:0] ex_rs2,
    input            ex_src1_used,
    input            ex_src2_used,

    //ex处理后信息
    input            ex_regWr,
    input            ex_memRd,
    input      [4:0] ex_waddr,

    //ex/mem寄存器内信息
    input            exmem_valid,
    input            exmem_regWr,
    input            exmem_memRd,
    input      [4:0] exmem_regwaddr,

    //mem/wb寄存器内信息
    input            wb_valid,
    input            wb_regWr,
    input      [4:0] wb_waddr,

    //输出
    output           load_use_stall,
    output reg [1:0] forwardA,
    output reg [1:0] forwardB
);
    localparam FWD_NONE  = 2'd0;
    localparam FWD_EXMEM = 2'd1;
    localparam FWD_MEMWB = 2'd2;

    assign load_use_stall = id_valid && ex_valid && ex_memRd && ex_regWr && (ex_waddr != 5'd0)
                            && ((id_src1_used && (id_rs1 == ex_waddr)) || (id_src2_used && (id_rs2 == ex_waddr)));
    
    always @(*) begin
        forwardA = FWD_NONE;

        if(ex_valid && ex_src1_used && exmem_valid && exmem_regWr && !exmem_memRd && (exmem_regwaddr != 5'd0) && (exmem_regwaddr == ex_rs1)) begin
            forwardA = FWD_EXMEM;
        end
        else if(ex_valid && ex_src1_used && wb_valid && wb_regWr && (wb_waddr != 5'd0) && (wb_waddr == ex_rs1)) begin
            forwardA = FWD_MEMWB;
        end
    end

    always @(*) begin
        forwardB = FWD_NONE;

        if(ex_valid && ex_src2_used && exmem_valid && exmem_regWr && !exmem_memRd && (exmem_regwaddr != 5'd0) && (exmem_regwaddr == ex_rs2)) begin
            forwardB = FWD_EXMEM;
        end
        else if(ex_valid && ex_src2_used && wb_valid && wb_regWr && (wb_waddr != 5'd0) && (wb_waddr == ex_rs2)) begin
            forwardB = FWD_MEMWB;
        end
    end

endmodule
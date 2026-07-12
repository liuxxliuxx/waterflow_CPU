`include "CPU_def.vh"

module CPU(
    input         clk,
    input         rst,

    input  [4:0]  test_addr,
    output [31:0] test_data,
    output [31:0] test_pc_cur,
    output [31:0] test_inst,

    output        inst_req_valid,
    input         inst_req_ready,
    output [31:0] inst_req_vaddr,

    input         inst_resp_valid,
    input  [31:0] inst_resp_data,
    input         inst_resp_err,


    output        data_req_valid,
    input         data_req_ready,
    output        data_req_we,
    output [31:0] data_req_vaddr,
    output [31:0] data_req_wdata,
    output [3:0]  data_req_wstrb,
    output [1:0]  data_req_size,

    input         data_resp_valid,
    input  [31:0] data_resp_rdata,
    input         data_resp_err,

    input  [7:0]  hw_int
);
    
    wire mem_stall;
    wire ex_stall;
    wire load_use_stall;
    wire csr_stall;
    wire fp_load_use_stall;


    wire redirect_valid;
    wire [31:0] redirect_pc;

    wire if_allowin = !mem_stall && !ex_stall && !load_use_stall && !csr_stall && !fp_load_use_stall;
    
    wire        if_valid;
    wire [31:0] if_pc;
    wire [31:0] if_pc4;
    wire [31:0] if_inst;
    wire        if_err;

    wire        bpu_pred_taken_raw;
    wire [31:0] bpu_pred_target_raw;

    wire        pred_taken  = if_valid ? bpu_pred_taken_raw  : 1'b0;
    wire [31:0] pred_target = if_valid ? bpu_pred_target_raw : 32'b0;



    wire [31:0] csr_rdata;
    wire [31:0] csr_eentry;
    wire [31:0] csr_era;
    wire        csr_has_int;
    wire [63:0] stable_timer;

    wire        csr_commit_we;
    wire [13:0] csr_commit_waddr;
    wire [1:0]  csr_commit_op;
    wire [31:0] csr_commit_wdata;
    wire [31:0] csr_commit_wmask;
    

    wire        exc_commit;
    wire [31:0] exc_commit_pc;
    wire [5:0]  exc_commit_ecode;
    wire [8:0]  exc_commit_esubcode;
    wire [31:0] exc_commit_badv;

    wire        ertn_commit;
    wire        mem_can_commit;


    reg        llbit;
    reg [31:0] lladdr;


    reg        ifid_valid;
    reg [31:0] ifid_pc;
    reg [31:0] ifid_pc4;
    reg [31:0] ifid_inst;
    reg        ifid_fetch_err;

    reg        ifid_exc_valid;
    reg [5:0]  ifid_exc_ecode;
    reg [8:0]  ifid_exc_esubcode;
    reg [31:0] ifid_exc_badv;

    reg        ifid_pred_taken;
    reg [31:0] ifid_pred_target;


    reg        idex_valid;
    reg [31:0] idex_pc;
    reg [31:0] idex_pc4;
    reg [31:0] idex_inst;
    reg [31:0] idex_rdata1;
    reg [31:0] idex_rdata2;
    reg [31:0] idex_imm32;
    reg [4:0]  idex_rs1;
    reg [4:0]  idex_rs2;
    reg [4:0]  idex_waddr;

    reg        idex_regWr;
    reg [3:0]  idex_branch;
    reg [4:0]  idex_ALUctr;
    reg        idex_ALUSrc1;
    reg [1:0]  idex_ALUSrc2;
    reg [2:0]  idex_alsl_shift;

    reg [1:0]  idex_UnitSel;
    reg [2:0]  idex_MDUctr;
    reg [3:0]  idex_FPUctr;

    reg        idex_MemWr;
    reg        idex_MemRd;
    reg        idex_MemEn;
    reg [1:0]  idex_MemSz;
    reg        idex_MemZeroExt;

    reg        idex_FpRegWr;
    reg [1:0]  idex_FPWB_Sel;

    reg [4:0]  idex_fp_rs1;
    reg [4:0]  idex_fp_rs2;
    reg [4:0]  idex_fp_waddr;

    reg [31:0] idex_fp_rdata1;
    reg [31:0] idex_fp_rdata2;

    reg        idex_FpSrc1Used;
    reg        idex_FpSrc2Used;

    reg        idex_MemSel;

    reg [3:0]  idex_WB_Sel;

    reg        idex_Src1Used;
    reg        idex_Src2Used;

    reg        idex_pred_taken;
    reg [31:0] idex_pred_target;

    reg        idex_exc_valid;
    reg [5:0]  idex_exc_ecode;
    reg [8:0]  idex_exc_esubcode;
    reg [31:0] idex_exc_badv;

    reg        idex_csr_en;
    reg        idex_csr_we;
    reg [1:0]  idex_csr_op;
    reg [13:0] idex_csr_num;
    reg [31:0] idex_csr_rdata;

    reg        idex_ertn;
    reg        idex_isll;
    reg        idex_issc;
    reg        idex_rdtime_inst;
    reg        idex_rdtime_high;
    reg [31:0] idex_timer_data;


    reg        exmem_valid;
    reg [31:0] exmem_ex_res;
    reg [31:0] exmem_store_data;
    reg [31:0] exmem_pc4;
    reg [4:0]  exmem_regwaddr;

    reg        exmem_regWr;

    reg        exmem_MemWr;
    reg        exmem_MemRd;
    reg        exmem_MemEn;
    reg [1:0]  exmem_MemSz;
    reg        exmem_MemZeroExt;

    reg [3:0]  exmem_WB_Sel;

    reg [31:0] exmem_fp_to_gp_data;

    reg [31:0] exmem_pc;
    reg        exmem_exc_valid;
    reg [5:0]  exmem_exc_ecode;
    reg [8:0]  exmem_exc_esubcode;
    reg [31:0] exmem_exc_badv;

    reg        exmem_csr_en;
    reg        exmem_csr_we;
    reg [1:0]  exmem_csr_op;
    reg [13:0] exmem_csr_num;
    reg [31:0] exmem_csr_rdata;
    reg [31:0] exmem_csr_wdata;
    reg [31:0] exmem_csr_wmask;

    reg        exmem_ertn;

    reg        exmem_isll;
    reg        exmem_issc;
    reg        exmem_sc_success;

    reg [31:0] exmem_timer_data; 

    reg        exmem_FpRegWr;
    reg [1:0]  exmem_FPWB_Sel;
    reg [4:0]  exmem_fp_waddr;

    reg [31:0] exmem_gp_to_fp_data;


    reg        memwb_valid;
    reg        memwb_regWr;
    reg [4:0]  memwb_waddr;
    reg [31:0] memwb_wdata;

    reg        memwb_FpRegWr;
    reg [4:0]  memwb_fp_waddr;
    reg [31:0] memwb_fp_wdata;



    wire if_pc_unalign = if_valid && (if_pc[1:0] != 2'b00);

    wire if_exc_valid = if_valid && (if_err || if_pc_unalign);

    wire [5:0] if_exc_ecode =
        if_pc_unalign ? `ECODE_ADEF :
        if_err        ? `ECODE_ADEF :
                        6'b0;

    wire [31:0] if_exc_badv = if_pc;

    

    IFU u_ifu(
        .clk(clk),
        .rst(rst),

        .if_allowin(if_allowin),

        .redirect_valid(redirect_valid),
        .redirect_pc(redirect_pc),

        .pred_taken(pred_taken),
        .pred_target(pred_target),

        .if_valid(if_valid),
        .if_pc(if_pc),
        .if_pc4(if_pc4),
        .if_inst(if_inst),
        .if_err(if_err),

        .inst_req_valid(inst_req_valid),
        .inst_req_ready(inst_req_ready),
        .inst_req_vaddr(inst_req_vaddr),

        .inst_resp_valid(inst_resp_valid),
        .inst_resp_data(inst_resp_data),
        .inst_resp_err(inst_resp_err)
    );

    wire        bpu_update_valid;
    wire [31:0] bpu_update_pc;
    wire        bpu_update_taken;
    wire [31:0] bpu_update_target;
    wire        bpu_update_is_cond;
    wire        bpu_update_is_jirl;

    BPU u_bpu(
        .clk(clk),
        .rst(rst),

        .if_pc(if_pc),
        .if_inst(if_inst),

        .pred_taken(bpu_pred_taken_raw),
        .pred_target(bpu_pred_target_raw),

        .update_valid(bpu_update_valid),
        .update_pc(bpu_update_pc),
        .update_taken(bpu_update_taken),
        .update_target(bpu_update_target),
        .update_is_cond(bpu_update_is_cond),
        .update_is_jirl(bpu_update_is_jirl)
    );

    

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            ifid_valid       <= 1'b0;
            ifid_pc          <= 32'b0;
            ifid_pc4         <= 32'b0;
            ifid_inst        <= 32'b0;
            ifid_fetch_err   <= 1'b0;
            ifid_pred_taken  <= 1'b0;
            ifid_pred_target <= 32'b0;
            ifid_exc_valid   <= 1'b0;
            ifid_exc_ecode   <= 6'b0;
            ifid_exc_esubcode<= 9'b0;
            ifid_exc_badv    <= 32'b0;
        end
        else if (redirect_valid) begin
            ifid_valid       <= 1'b0;
            ifid_pc          <= 32'b0;
            ifid_pc4         <= 32'b0;
            ifid_inst        <= 32'b0;
            ifid_fetch_err   <= 1'b0;
            ifid_pred_taken  <= 1'b0;
            ifid_pred_target <= 32'b0;
            ifid_exc_valid   <= 1'b0;
            ifid_exc_ecode   <= 6'b0;
            ifid_exc_esubcode<= 9'b0;
            ifid_exc_badv    <= 32'b0;
        end
        else if (mem_stall || ex_stall || load_use_stall || csr_stall || fp_load_use_stall) begin
            ifid_valid       <= ifid_valid;
            ifid_pc          <= ifid_pc;
            ifid_pc4         <= ifid_pc4;
            ifid_inst        <= ifid_inst;
            ifid_fetch_err   <= ifid_fetch_err;
            ifid_pred_taken  <= ifid_pred_taken;
            ifid_pred_target <= ifid_pred_target;
            ifid_exc_valid   <= ifid_exc_valid;
            ifid_exc_ecode   <= ifid_exc_ecode;
            ifid_exc_esubcode<= ifid_exc_esubcode;
            ifid_exc_badv    <= ifid_exc_badv;
        end
        else if (if_valid) begin
            ifid_valid       <= 1'b1;
            ifid_pc          <= if_pc;
            ifid_pc4         <= if_pc4;
            ifid_inst        <= if_inst;
            ifid_fetch_err   <= if_err;
            ifid_pred_taken  <= pred_taken;
            ifid_pred_target <= pred_target;
            ifid_exc_valid   <= if_exc_valid;
            ifid_exc_ecode   <= if_exc_ecode;
            ifid_exc_esubcode<= 9'b0;
            ifid_exc_badv    <= if_exc_badv;
        end
        else begin
            ifid_valid       <= 1'b0;
            ifid_pc          <= 32'b0;
            ifid_pc4         <= 32'b0;
            ifid_inst        <= 32'b0;
            ifid_fetch_err   <= 1'b0;
            ifid_pred_taken  <= 1'b0;
            ifid_pred_target <= 32'b0;
            ifid_exc_valid   <= 1'b0;
            ifid_exc_ecode   <= 6'b0;
            ifid_exc_esubcode<= 9'b0;
            ifid_exc_badv    <= 32'b0;
        end
    end

    wire [31:0] id_inst = ifid_inst;

    wire        id_regWr;
    wire [3:0]  id_branch;
    wire        id_RegDst;
    wire        id_RegDst1;
    wire [4:0]  id_ALUctr;
    wire        id_ALUSrc1;
    wire [1:0]  id_ALUSrc2;
    wire        id_Src1Used;
    wire        id_Src2Used;
    wire [3:0]  id_ImmType;

    wire        id_MemWr;
    wire        id_MemRd;
    wire        id_MemEn;
    wire [1:0]  id_MemSz;
    wire        id_MemSel;
    wire        id_MemZeroExt;

    wire [2:0]  id_alsl_shift;

    wire [1:0]  id_UnitSel;
    wire [2:0]  id_MDUctr;

    wire        id_need_priv;
    wire        id_inst_valid;
    wire        id_fp_inst;
    wire        id_trap_sys;
    wire        id_trap_brk;
    wire        id_rdtime_inst;

    wire        id_csr_en;
    wire        id_csr_we;
    wire [1:0]  id_csr_op;
    wire [13:0] id_csr_num;
    wire [2:0]  id_specop;

    wire        id_FpRegWr;
    wire [3:0]  id_FPUctr;
    wire        id_FptoGpr;
    wire        id_GprtoFp;
    wire        id_FpSrc2;
    wire        id_FpSrc1Used;
    wire        id_FpSrc2Used;

    wire [3:0]  id_WB_Sel;
    wire [1:0]  id_FPWB_Sel;

    wire        id_issc;
    wire        id_isll;

    Control_Unit u_ctrl(
        .inst(id_inst),

        .regWr(id_regWr),
        .branch(id_branch),
        .RegDst(id_RegDst),
        .RegDst1(id_RegDst1),
        .ALUctr(id_ALUctr),
        .ALUSrc1(id_ALUSrc1),
        .ALUSrc2(id_ALUSrc2),
        .Src1Used(id_Src1Used),
        .Src2Used(id_Src2Used),
        .ImmType(id_ImmType),

        .MemWr(id_MemWr),
        .MemRd(id_MemRd),
        .MemEn(id_MemEn),
        .MemSz(id_MemSz),
        .MemSel(id_MemSel),
        .MemZeroExt(id_MemZeroExt),

        .alsl_shift(id_alsl_shift),

        .UnitSel(id_UnitSel),
        .MDUctr(id_MDUctr),

        .need_priv(id_need_priv),
        .inst_valid(id_inst_valid),
        .fp_inst(id_fp_inst),
        .trap_sys(id_trap_sys),
        .trap_brk(id_trap_brk),
        .rdtime_inst(id_rdtime_inst),

        .csr_en(id_csr_en),
        .csr_we(id_csr_we),
        .csr_op(id_csr_op),
        .csr_num(id_csr_num),
        .specop(id_specop),

        .FpRegWr(id_FpRegWr),
        .FPUctr(id_FPUctr),
        .FptoGpr(id_FptoGpr),
        .GprtoFp(id_GprtoFp),
        .FpSrc2(id_FpSrc2),
        .FpSrc1Used(id_FpSrc1Used),
        .FpSrc2Used(id_FpSrc2Used),

        .WB_Sel(id_WB_Sel),
        .FPWB_Sel(id_FPWB_Sel),

        .issc(id_issc),
        .isll(id_isll)
    );


    wire csr_plv_is_user = 1'b0; 
    // 如果你暂时不做用户态，先写 0。
    // 后面可以从 CSRFile 输出 csr_crmd_plv。
    assign csr_stall = ifid_valid && id_csr_en && ((idex_valid && idex_csr_we) || (exmem_valid && exmem_csr_we));

    wire id_exc_ine = ifid_valid && !ifid_exc_valid && !id_inst_valid;
    wire id_exc_sys = ifid_valid && !ifid_exc_valid && id_trap_sys;
    wire id_exc_brk = ifid_valid && !ifid_exc_valid && id_trap_brk;
    wire id_exc_ipe = ifid_valid && !ifid_exc_valid && id_need_priv && csr_plv_is_user;

    // 中断也可以当成 ID 阶段异常处理。
    // 注意中断应该发生在指令边界，这样比较简单。
    wire id_exc_int = ifid_valid && !ifid_exc_valid && csr_has_int;

    reg        id_exc_valid;
    reg [5:0]  id_exc_ecode;
    reg [8:0]  id_exc_esubcode;
    reg [31:0] id_exc_badv;

    always @(*) begin
        id_exc_valid    = 1'b0;
        id_exc_ecode    = 6'b0;
        id_exc_esubcode = 9'b0;
        id_exc_badv     = 32'b0;

        if (ifid_exc_valid) begin
            id_exc_valid = 1'b1;
            id_exc_ecode = ifid_exc_ecode;
            id_exc_esubcode = ifid_exc_esubcode;
            id_exc_badv = ifid_exc_badv;
        end
        else if (id_exc_int) begin
            id_exc_valid = 1'b1;
            id_exc_ecode = `ECODE_INT;
            id_exc_badv  = 32'b0;
        end
        else if (id_exc_ine) begin
            id_exc_valid = 1'b1;
            id_exc_ecode = `ECODE_INE;
        end
        else if (id_exc_sys) begin
            id_exc_valid = 1'b1;
            id_exc_ecode = `ECODE_SYS;
        end
        else if (id_exc_brk) begin
            id_exc_valid = 1'b1;
            id_exc_ecode = `ECODE_BRK;
        end
        else if (id_exc_ipe) begin
            id_exc_valid = 1'b1;
            id_exc_ecode = `ECODE_IPE;
        end
    end
    
    wire [31:0] id_imm32;

    ImmGen u_imm(
        .inst(id_inst),
        .ImmType(id_ImmType),
        .imm32(id_imm32)
    );

    wire [4:0] id_rs1   = id_inst[9:5];
    wire [4:0] id_rs2   = id_RegDst ? id_inst[4:0] : id_inst[14:10];
    wire [4:0] id_waddr = id_RegDst1 ? 5'd1 : id_inst[4:0];

    wire [31:0] id_rdata1_raw;
    wire [31:0] id_rdata2_raw;

    reg_32bit u_reg(
        .clk(clk),
        .rst(rst),

        .raddr1(id_rs1),
        .rdata1(id_rdata1_raw),

        .raddr2(id_rs2),
        .rdata2(id_rdata2_raw),

        .wen(memwb_valid && memwb_regWr),
        .waddr(memwb_waddr),
        .wdata(memwb_wdata),

        .test_addr(test_addr),
        .test_data(test_data)
    );


    wire [4:0] id_fp_rs1   = id_inst[9:5];
    wire [4:0] id_fp_rs2   = id_FpSrc2 ? id_inst[4:0] : id_inst[14:10];
    wire [4:0] id_fp_waddr = id_inst[4:0];

    wire [31:0] id_fp_rdata1_raw;
    wire [31:0] id_fp_rdata2_raw;
    wire [31:0] fp_test_data_unused;

    freg_32bit u_freg(
        .clk(clk),
        .rst(rst),

        .raddr1(id_fp_rs1),
        .raddr2(id_fp_rs2),
        .rdata1(id_fp_rdata1_raw),
        .rdata2(id_fp_rdata2_raw),

        .wen(memwb_valid && memwb_FpRegWr),
        .waddr(memwb_fp_waddr),
        .wdata(memwb_fp_wdata),

        .test_addr(test_addr),
        .test_data(fp_test_data_unused)
    );

    wire [31:0] id_fp_rdata1 = (ifid_valid && id_FpSrc1Used && memwb_valid && memwb_FpRegWr && (memwb_fp_waddr == id_fp_rs1)) ? memwb_fp_wdata : id_fp_rdata1_raw;

    wire [31:0] id_fp_rdata2 = (ifid_valid && id_FpSrc2Used && memwb_valid && memwb_FpRegWr && (memwb_fp_waddr == id_fp_rs2)) ? memwb_fp_wdata : id_fp_rdata2_raw;

    assign fp_load_use_stall = ifid_valid && idex_valid && idex_MemRd && idex_FpRegWr && ((id_FpSrc1Used && (id_fp_rs1 == idex_fp_waddr)) ||(id_FpSrc2Used && (id_fp_rs2 == idex_fp_waddr)));

    wire [31:0] id_rdata1 =
        (ifid_valid && id_Src1Used &&
        memwb_valid && memwb_regWr &&
        (memwb_waddr != 5'd0) &&
        (memwb_waddr == id_rs1)) ? memwb_wdata : id_rdata1_raw;

    wire [31:0] id_rdata2 =
        (ifid_valid && id_Src2Used &&
        memwb_valid && memwb_regWr &&
        (memwb_waddr != 5'd0) &&
        (memwb_waddr == id_rs2)) ? memwb_wdata : id_rdata2_raw;

    
    
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            idex_valid  <= 1'b0;
            idex_regWr  <= 1'b0;
            idex_MemWr  <= 1'b0;
            idex_MemRd  <= 1'b0;
            idex_MemEn  <= 1'b0;
            idex_branch <= `BR_NONE;
            idex_WB_Sel <= `WB_ALU;
            idex_exc_valid <= 1'b0;
            idex_csr_en    <= 1'b0;
            idex_csr_we    <= 1'b0;
            idex_ertn      <= 1'b0;
            idex_isll      <= 1'b0;
            idex_issc      <= 1'b0;
            idex_rdtime_inst <= 1'b0;

            idex_FpRegWr      <= 1'b0;
            idex_FPWB_Sel     <= `FPWB_FPU;
            idex_fp_rs1       <= 5'b0;
            idex_fp_rs2       <= 5'b0;
            idex_fp_waddr     <= 5'b0;
            idex_fp_rdata1    <= 32'b0;
            idex_fp_rdata2    <= 32'b0;
            idex_FpSrc1Used   <= 1'b0;
            idex_FpSrc2Used   <= 1'b0;
            idex_MemSel       <= 1'b0;
        end
        else if(redirect_valid) begin
            idex_valid <= 1'b0;
            idex_regWr <= 1'b0;
            idex_MemWr <= 1'b0;
            idex_MemRd <= 1'b0;
            idex_MemEn <= 1'b0;
            idex_branch <= `BR_NONE;
            idex_WB_Sel <= `WB_ALU;

            idex_exc_valid   <= 1'b0;
            idex_csr_en      <= 1'b0;
            idex_csr_we      <= 1'b0;
            idex_ertn        <= 1'b0;
            idex_isll        <= 1'b0;
            idex_issc        <= 1'b0;
            idex_rdtime_inst <= 1'b0;

            idex_FpRegWr    <= 1'b0;
            idex_FpSrc1Used <= 1'b0;
            idex_FpSrc2Used <= 1'b0;
            idex_MemSel     <= 1'b0;
        end
        else if (mem_stall || ex_stall) begin
            idex_valid <= idex_valid;
        end
        else if (load_use_stall || fp_load_use_stall || csr_stall) begin
            idex_valid <= 1'b0;
            idex_regWr <= 1'b0;
            idex_MemWr <= 1'b0;
            idex_MemRd <= 1'b0;
            idex_MemEn <= 1'b0;
            idex_branch <= `BR_NONE;
            idex_WB_Sel <= `WB_ALU;

            idex_exc_valid   <= 1'b0;
            idex_csr_en      <= 1'b0;
            idex_csr_we      <= 1'b0;
            idex_ertn        <= 1'b0;
            idex_isll        <= 1'b0;
            idex_issc        <= 1'b0;
            idex_rdtime_inst <= 1'b0;

            idex_FpRegWr    <= 1'b0;
            idex_FpSrc1Used <= 1'b0;
            idex_FpSrc2Used <= 1'b0;
            idex_MemSel     <= 1'b0;
        end
        else begin
            idex_valid      <= ifid_valid;
            idex_pc         <= ifid_pc;
            idex_pc4        <= ifid_pc4;
            idex_inst       <= ifid_inst;
            idex_rdata1     <= id_rdata1;
            idex_rdata2     <= id_rdata2;
            idex_imm32      <= id_imm32;
            idex_rs1        <= id_rs1;
            idex_rs2        <= id_rs2;
            idex_waddr      <= id_waddr;

            idex_regWr      <= ifid_valid && id_regWr && !id_exc_valid;
            idex_branch     <= (ifid_valid && !id_exc_valid) ? id_branch : `BR_NONE;
            idex_ALUctr     <= id_ALUctr;
            idex_ALUSrc1    <= id_ALUSrc1;
            idex_ALUSrc2    <= id_ALUSrc2;
            idex_alsl_shift <= id_alsl_shift;

            idex_UnitSel    <= id_UnitSel;
            idex_MDUctr     <= id_MDUctr;
            idex_FPUctr     <= id_FPUctr;

            idex_MemWr      <= ifid_valid && id_MemWr && !id_exc_valid;
            idex_MemRd      <= ifid_valid && id_MemRd && !id_exc_valid;
            idex_MemEn      <= ifid_valid && id_MemEn && !id_exc_valid;
            idex_MemSz      <= id_MemSz;
            idex_MemZeroExt <= id_MemZeroExt;

            idex_WB_Sel     <= id_WB_Sel;

            idex_Src1Used   <= id_Src1Used;
            idex_Src2Used   <= id_Src2Used;

            idex_pred_taken  <= ifid_pred_taken;
            idex_pred_target <= ifid_pred_target;

            idex_exc_valid    <= ifid_valid && id_exc_valid;
            idex_exc_ecode    <= id_exc_ecode;
            idex_exc_esubcode <= id_exc_esubcode;
            idex_exc_badv     <= id_exc_badv;

            idex_csr_en       <= ifid_valid && id_csr_en;
            idex_csr_we       <= ifid_valid && id_csr_we && !id_exc_valid;
            idex_csr_op       <= id_csr_op;
            idex_csr_num      <= id_csr_num;
            idex_csr_rdata    <= csr_rdata;

            idex_ertn         <= ifid_valid && (id_specop == `SP_ERTN) && !id_exc_valid;

            // LL/SC
            idex_isll         <= ifid_valid && id_isll && !id_exc_valid;
            idex_issc         <= ifid_valid && id_issc && !id_exc_valid;

            // rdtime
            idex_rdtime_inst  <= ifid_valid && id_rdtime_inst && !id_exc_valid;
            idex_rdtime_high  <= (id_inst[14:10] == 5'h19);
            idex_timer_data   <= (id_inst[14:10] == 5'h19) ? stable_timer[63:32]
                                                            : stable_timer[31:0];
            
            idex_FpRegWr    <= ifid_valid && id_FpRegWr && !id_exc_valid;
            idex_FPWB_Sel   <= id_FPWB_Sel;

            idex_fp_rs1     <= id_fp_rs1;
            idex_fp_rs2     <= id_fp_rs2;
            idex_fp_waddr   <= id_fp_waddr;

            idex_fp_rdata1  <= id_fp_rdata1;
            idex_fp_rdata2  <= id_fp_rdata2;

            idex_FpSrc1Used <= id_FpSrc1Used;
            idex_FpSrc2Used <= id_FpSrc2Used;

            idex_MemSel     <= id_MemSel;

        end
    end

    wire [1:0] forwardA;
    wire [1:0] forwardB;

    HazardUnit u_hazard(
        .id_valid(ifid_valid),
        .id_rs1(id_rs1),
        .id_rs2(id_rs2),
        .id_src1_used(id_Src1Used),
        .id_src2_used(id_Src2Used),

        .ex_valid(idex_valid),
        .ex_rs1(idex_rs1),
        .ex_rs2(idex_rs2),
        .ex_src1_used(idex_Src1Used),
        .ex_src2_used(idex_Src2Used),

        .ex_regWr(idex_regWr),
        .ex_memRd(idex_MemRd),
        .ex_waddr(idex_waddr),

        .exmem_valid(exmem_valid),
        .exmem_regWr(exmem_regWr),
        .exmem_memRd(exmem_MemRd),
        .exmem_regwaddr(exmem_regwaddr),

        .wb_valid(memwb_valid),
        .wb_regWr(memwb_regWr),
        .wb_waddr(memwb_waddr),

        .load_use_stall(load_use_stall),
        .forwardA(forwardA),
        .forwardB(forwardB)
    );
    reg [31:0] exmem_forward_data;

    reg [31:0] ex_data1;
    reg [31:0] ex_data2;

    always @(*) begin
        case (forwardA)
            2'd1:    ex_data1 = exmem_forward_data;
            2'd2:    ex_data1 = memwb_wdata;
            default: ex_data1 = idex_rdata1;
        endcase
    end

    always @(*) begin
        case (forwardB)
            2'd1:    ex_data2 = exmem_forward_data;
            2'd2:    ex_data2 = memwb_wdata;
            default: ex_data2 = idex_rdata2;
        endcase
    end



    wire        ex_ready;
    wire        ex_busy;
    wire        ex_res_valid;
    wire [31:0] ex_res;
    wire        ex_flush = exc_commit || ertn_commit;

    wire [31:0] ex_branch_target;
    wire        ex_take_branch_raw;
    wire        ex_branch_valid;
    wire        ex_branch_cond;
    wire        ex_branch_jirl;

    wire [31:0] ex_fp_to_gp_data;
    wire [31:0] ex_gp_to_fp_data;

    reg [31:0] exmem_fp_forward_data;

    always @(*) begin
        case(exmem_FPWB_Sel)
            `FPWB_FPU: begin
                exmem_fp_forward_data = exmem_ex_res;
            end

            `FPWB_GPR: begin
                exmem_fp_forward_data = exmem_gp_to_fp_data;
            end

            // fld.s 不能从 EX/MEM 转发，必须等 MEM/WB
            `FPWB_MEM: begin
                exmem_fp_forward_data = 32'b0;
            end

            default: begin
                exmem_fp_forward_data = exmem_ex_res;
            end

        endcase
    end 

    wire        ex_stage_exc_valid;
    wire [5:0]  ex_stage_exc_ecode;

    wire exmem_ready = !mem_stall;

    reg [31:0] ex_fp_data1;
    reg [31:0] ex_fp_data2;

    always @(*) begin
        if (idex_valid &&
            idex_FpSrc1Used &&
            exmem_valid &&
            exmem_FpRegWr &&
            (exmem_FPWB_Sel != `FPWB_MEM) &&
            (exmem_fp_waddr == idex_fp_rs1)) begin
            ex_fp_data1 = exmem_fp_forward_data;
        end
        else if (idex_valid &&
                idex_FpSrc1Used &&
                memwb_valid &&
                memwb_FpRegWr &&
                (memwb_fp_waddr == idex_fp_rs1)) begin
            ex_fp_data1 = memwb_fp_wdata;
        end
        else begin
            ex_fp_data1 = idex_fp_rdata1;
        end
    end

    always @(*) begin
        if (idex_valid &&
            idex_FpSrc2Used &&
            exmem_valid &&
            exmem_FpRegWr &&
            (exmem_FPWB_Sel != `FPWB_MEM) &&
            (exmem_fp_waddr == idex_fp_rs2)) begin
            ex_fp_data2 = exmem_fp_forward_data;
        end
        else if (idex_valid &&
                idex_FpSrc2Used &&
                memwb_valid &&
                memwb_FpRegWr &&
                (memwb_fp_waddr == idex_fp_rs2)) begin
            ex_fp_data2 = memwb_fp_wdata;
        end
        else begin
            ex_fp_data2 = idex_fp_rdata2;
        end
    end

    EXU u_exu(
        .clk(clk),
        .rst(rst),

        .pc(idex_pc),
        .rdata1(ex_data1),
        .rdata2(ex_data2),
        .imm32(idex_imm32),

        .flush(ex_flush),
        .ex_valid(idex_valid),
        .exmem_ready(exmem_ready),

        .fp_rdata1(ex_fp_data1),
        .fp_rdata2(ex_fp_data2),

        .branch(idex_branch),

        .ALUSrc1(idex_ALUSrc1),
        .ALUSrc2(idex_ALUSrc2),
        .alsl_shift(idex_alsl_shift),

        .UnitSel(idex_UnitSel),
        .MDUctr(idex_MDUctr),
        .FPUctr(idex_FPUctr),
        .ALUctr(idex_ALUctr),

        .ex_busy(ex_busy),
        .ex_ready(ex_ready),
        .ex_res_valid(ex_res_valid),

        .ex_res(ex_res),
        .fp_to_gp_data(ex_fp_to_gp_data),
        .gp_to_fp_data(ex_gp_to_fp_data),

        .branch_target(ex_branch_target),
        .take_branch(ex_take_branch_raw),
        .branch_valid(ex_branch_valid),
        .branch_cond(ex_branch_cond),
        .branch_jirl(ex_branch_jirl),
        .ex_exc_valid(ex_stage_exc_valid),
        .ex_exc_ecode(ex_stage_exc_ecode)
    );

    

    always @(*) begin
        case(exmem_WB_Sel)
            `WB_ALU: begin
                exmem_forward_data = exmem_ex_res;
            end

            `WB_MDU: begin
                exmem_forward_data = exmem_ex_res;
            end

            `WB_CPUCFG: begin
                exmem_forward_data = exmem_ex_res;
            end

            `WB_PC4: begin
                exmem_forward_data = exmem_pc4;
            end

            `WB_CSR: begin
                exmem_forward_data = exmem_csr_rdata;
            end

            `WB_TIMER: begin
                exmem_forward_data = exmem_timer_data;
            end

            `WB_SC: begin
                exmem_forward_data = exmem_sc_success ? 32'd1 : 32'd0;
            end

            `WB_FPR: begin
                exmem_forward_data = exmem_fp_to_gp_data;
            end

            // load / ll.w 不能从 EX/MEM 转发，必须等 MEM/WB
            `WB_MEM: begin
                exmem_forward_data = 32'b0;
            end

            default: begin
                exmem_forward_data = exmem_ex_res;
            end

        endcase
    end

    assign ex_stall = idex_valid && !ex_ready;



    wire ex_branch_fire =
        idex_valid &&
        ex_res_valid &&
        ex_branch_valid &&
        !mem_stall &&
        !ex_flush;

    wire pred_miss =
        ex_branch_fire &&
        (
            (idex_pred_taken != ex_take_branch_raw) ||
            (ex_take_branch_raw && (idex_pred_target != ex_branch_target))
        );

    assign redirect_valid = exc_commit || ertn_commit || pred_miss;
    assign redirect_pc    = exc_commit ? csr_eentry : 
                            ertn_commit ? csr_era   :
                            ex_take_branch_raw ? ex_branch_target : idex_pc4;


    assign bpu_update_valid   = ex_branch_fire;
    assign bpu_update_pc      = idex_pc;
    assign bpu_update_taken   = ex_take_branch_raw;
    assign bpu_update_target  = ex_branch_target;
    assign bpu_update_is_cond = ex_branch_cond;
    assign bpu_update_is_jirl = ex_branch_jirl;


    

    CSRFile u_csr(
        .clk(clk),
        .rst(rst),

        .csr_raddr(id_csr_num),
        .csr_rdata(csr_rdata),

        .csr_we(csr_commit_we),
        .csr_waddr(csr_commit_waddr),
        .csr_op(csr_commit_op),
        .csr_wdata(csr_commit_wdata),
        .csr_wmask(csr_commit_wmask),

        .exc_valid(exc_commit),
        .exc_pc(exc_commit_pc),
        .exc_ecode(exc_commit_ecode),
        .exc_esubcode(exc_commit_esubcode),
        .exc_badv(exc_commit_badv),

        .ertn_valid(ertn_commit),

        .hw_int(hw_int),

        .csr_eentry(csr_eentry),
        .csr_era(csr_era),
        .has_int(csr_has_int),

        .stable_timer(stable_timer)
    );


    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            exmem_valid      <= 1'b0;
            exmem_regWr      <= 1'b0;
            exmem_MemWr      <= 1'b0;
            exmem_MemRd      <= 1'b0;
            exmem_MemEn      <= 1'b0;
            exmem_ex_res     <= 32'b0;
            exmem_store_data <= 32'b0;
            exmem_pc4        <= 32'b0;
            exmem_regwaddr   <= 5'b0;
            exmem_WB_Sel     <= `WB_ALU;

            exmem_exc_valid <= 1'b0;
            exmem_csr_en    <= 1'b0;
            exmem_csr_we    <= 1'b0;
            exmem_ertn      <= 1'b0;
            exmem_isll      <= 1'b0;
            exmem_issc      <= 1'b0;
            exmem_sc_success <= 1'b0;

            exmem_pc            <= 32'b0;
            exmem_exc_ecode     <= 6'b0;
            exmem_exc_esubcode  <= 9'b0;
            exmem_exc_badv      <= 32'b0;

            exmem_csr_op        <= `CSR_RD;
            exmem_csr_num       <= 14'b0;
            exmem_csr_rdata     <= 32'b0;
            exmem_csr_wdata     <= 32'b0;
            exmem_csr_wmask     <= 32'b0;

            exmem_timer_data    <= 32'b0;

            exmem_FpRegWr       <= 1'b0;
            exmem_FPWB_Sel      <= `FPWB_FPU;
            exmem_fp_waddr      <= 5'b0;
            exmem_gp_to_fp_data <= 32'b0;
        end
        else if (mem_stall) begin
            exmem_valid <= exmem_valid;
            exmem_ex_res        <= exmem_ex_res;
            exmem_store_data    <= exmem_store_data;
            exmem_pc4           <= exmem_pc4;
            exmem_regwaddr         <= exmem_regwaddr;

            exmem_regWr         <= exmem_regWr;
            exmem_MemWr         <= exmem_MemWr;
            exmem_MemRd         <= exmem_MemRd;
            exmem_MemEn         <= exmem_MemEn;
            exmem_MemSz         <= exmem_MemSz;
            exmem_MemZeroExt    <= exmem_MemZeroExt;
            exmem_WB_Sel        <= exmem_WB_Sel;
            exmem_fp_to_gp_data <= exmem_fp_to_gp_data;

            exmem_FpRegWr       <= exmem_FpRegWr;
            exmem_FPWB_Sel      <= exmem_FPWB_Sel;
            exmem_fp_waddr      <= exmem_fp_waddr;
            exmem_gp_to_fp_data <= exmem_gp_to_fp_data;
        end
        else if (ex_flush) begin
            exmem_valid   <= 1'b0;
            exmem_regWr   <= 1'b0;
            exmem_MemWr   <= 1'b0;
            exmem_MemRd   <= 1'b0;
            exmem_MemEn   <= 1'b0;
            exmem_FpRegWr <= 1'b0;
        end
        else if(ex_stall) begin
            exmem_valid         <= 1'b0;
            exmem_regWr         <= 1'b0;
            exmem_MemWr         <= 1'b0;
            exmem_MemRd         <= 1'b0;
            exmem_MemEn         <= 1'b0;
            exmem_FpRegWr       <= 1'b0;
        end
        else begin
            exmem_valid      <= idex_valid && ex_res_valid;
            exmem_ex_res     <= ex_res;
            exmem_store_data <= idex_MemSel ? ex_fp_data2 : ex_data2;
            exmem_pc         <= idex_pc;
            exmem_pc4        <= idex_pc4;
            exmem_regwaddr      <= idex_waddr;

            exmem_exc_valid <= idex_valid &&
                       ex_res_valid &&
                       (idex_exc_valid || ex_stage_exc_valid);

            exmem_exc_ecode <= idex_exc_valid ? idex_exc_ecode :
                            ex_stage_exc_valid ? ex_stage_exc_ecode :
                            6'b0;

            exmem_exc_esubcode <= idex_exc_valid ? idex_exc_esubcode : 9'b0;

            exmem_exc_badv <= idex_exc_valid ? idex_exc_badv : 32'b0;




            exmem_regWr      <= idex_valid && ex_res_valid && idex_regWr && !(idex_exc_valid || ex_stage_exc_valid);
            exmem_MemWr      <= idex_valid && ex_res_valid && idex_MemWr && !(idex_exc_valid || ex_stage_exc_valid);
            exmem_MemRd      <= idex_valid && ex_res_valid && idex_MemRd && !(idex_exc_valid || ex_stage_exc_valid);
            exmem_MemEn      <= idex_valid && ex_res_valid && idex_MemEn && !(idex_exc_valid || ex_stage_exc_valid);


            exmem_MemSz      <= idex_MemSz;
            exmem_MemZeroExt <= idex_MemZeroExt;

            exmem_WB_Sel     <= idex_WB_Sel;


            exmem_csr_en    <= idex_valid && ex_res_valid && idex_csr_en;
            exmem_csr_we    <= idex_valid &&
                            ex_res_valid &&
                            idex_csr_we &&
                            !(idex_exc_valid || ex_stage_exc_valid);
            exmem_csr_op    <= idex_csr_op;
            exmem_csr_num   <= idex_csr_num;
            exmem_csr_rdata <= idex_csr_rdata;

            exmem_csr_wdata <= ex_data2;
            exmem_csr_wmask <= ex_data1;

            exmem_ertn <= idex_valid &&
                          ex_res_valid &&
                          idex_ertn &&
                          !(idex_exc_valid || ex_stage_exc_valid);

            exmem_isll <= idex_valid &&
                          ex_res_valid &&
                          idex_isll &&
                          !(idex_exc_valid || ex_stage_exc_valid);

            exmem_issc <= idex_valid &&
                          ex_res_valid &&
                          idex_issc &&
                          !(idex_exc_valid || ex_stage_exc_valid);

            exmem_sc_success <= idex_valid &&
                                ex_res_valid &&
                                idex_issc &&
                                llbit &&
                                (lladdr == ex_res) &&
                                !(idex_exc_valid || ex_stage_exc_valid);

            exmem_timer_data <= idex_timer_data;

            exmem_FpRegWr <= idex_valid &&
                 ex_res_valid &&
                 idex_FpRegWr &&
                 !(idex_exc_valid || ex_stage_exc_valid);

            exmem_FPWB_Sel <= idex_FPWB_Sel;
            exmem_fp_waddr <= idex_fp_waddr;

            exmem_gp_to_fp_data <= ex_gp_to_fp_data;

            exmem_fp_to_gp_data <= ex_fp_to_gp_data;
        end
    end

    wire        lsu_mem_ready;
    wire        lsu_mem_stall;
    wire [31:0] lsu_load_data;
    wire        lsu_addr_err;
    wire        lsu_bus_err;

    wire memwb_accept = exmem_valid && lsu_mem_ready;

    wire lsu_mem_en = exmem_MemEn &&
                  (!exmem_issc || exmem_sc_success);

    wire lsu_mem_wr = exmem_MemWr &&
                    (!exmem_issc || exmem_sc_success);

    LSU u_lsu(
        .clk(clk),
        .rst(rst),
        .flush(1'b0),

        .mem_valid(exmem_valid),
        .mem_en(lsu_mem_en),
        .mem_wr(lsu_mem_wr),
        .mem_rd(exmem_MemRd),
        .mem_size(exmem_MemSz),
        .mem_zero_ext(exmem_MemZeroExt),
        .mem_addr(exmem_ex_res),
        .mem_wdata(exmem_store_data),

        .result_taken(memwb_accept),

        .mem_ready(lsu_mem_ready),
        .mem_stall(lsu_mem_stall),

        .load_data(lsu_load_data),
        .addr_err(lsu_addr_err),
        .bus_err(lsu_bus_err),

        .data_req_valid(data_req_valid),
        .data_req_ready(data_req_ready),
        .data_req_we(data_req_we),
        .data_req_vaddr(data_req_vaddr),
        .data_req_wdata(data_req_wdata),
        .data_req_wstrb(data_req_wstrb),
        .data_req_size(data_req_size),

        .data_resp_valid(data_resp_valid),
        .data_resp_rdata(data_resp_rdata),
        .data_resp_err(data_resp_err)
    );

    wire mem_lsu_addr_exc = exmem_valid && lsu_addr_err;
    wire mem_lsu_bus_exc  = exmem_valid && lsu_bus_err;

    wire mem_exc_valid = exmem_valid &&
                        (
                            exmem_exc_valid ||
                            mem_lsu_addr_exc ||
                            mem_lsu_bus_exc
                        );
    reg [5:0]  mem_exc_ecode;
    reg [8:0]  mem_exc_esubcode;
    reg [31:0] mem_exc_badv;
    
    always @(*) begin
        if (exmem_exc_valid) begin
            mem_exc_ecode    = exmem_exc_ecode;
            mem_exc_esubcode = exmem_exc_esubcode;
            mem_exc_badv     = exmem_exc_badv;
        end
        else if (mem_lsu_addr_exc) begin
            mem_exc_ecode    = `ECODE_ALE;
            mem_exc_esubcode = 9'b0;
            mem_exc_badv     = exmem_ex_res;
        end
        else if (mem_lsu_bus_exc) begin
            mem_exc_ecode    = `ECODE_ADEM;
            mem_exc_esubcode = 9'b0;
            mem_exc_badv     = exmem_ex_res;
        end
        else begin
            mem_exc_ecode    = exmem_exc_ecode;
            mem_exc_esubcode = exmem_exc_esubcode;
            mem_exc_badv     = exmem_exc_badv;
        end
    end

    assign ertn_commit = exmem_valid &&
                         lsu_mem_ready &&
                         exmem_ertn &&
                         !mem_exc_valid;
    
    assign mem_can_commit = exmem_valid &&
                            lsu_mem_ready &&
                            !mem_exc_valid &&
                            !ertn_commit;


    assign exc_commit = exmem_valid &&
                        lsu_mem_ready &&
                        mem_exc_valid;

    assign exc_commit_pc       = exmem_pc;
    assign exc_commit_ecode    = mem_exc_ecode;
    assign exc_commit_esubcode = mem_exc_esubcode;
    assign exc_commit_badv     = mem_exc_badv;

    assign csr_commit_we = mem_can_commit &&
                           exmem_csr_we;

    assign csr_commit_waddr = exmem_csr_num;
    assign csr_commit_op    = exmem_csr_op;
    assign csr_commit_wdata = exmem_csr_wdata;
    assign csr_commit_wmask = exmem_csr_wmask;

    

    assign mem_stall = lsu_mem_stall;

    reg [31:0] mem_stage_wdata;

    always @(*) begin
        case (exmem_WB_Sel)
            `WB_MEM: begin
                mem_stage_wdata = lsu_load_data;
            end

            `WB_ALU: begin
                mem_stage_wdata = exmem_ex_res;
            end

            `WB_MDU: begin
                mem_stage_wdata = exmem_ex_res;
            end

            `WB_PC4: begin
                mem_stage_wdata = exmem_pc4;
            end

            `WB_FPR: begin
                mem_stage_wdata = exmem_fp_to_gp_data;
            end

            `WB_SC: begin
                // LL/SC 还没做，先临时返回 1
                mem_stage_wdata = exmem_sc_success ? 32'd1 : 32'd0;
            end

            `WB_CPUCFG: begin
                // 如果 ALU_CPUCFG 已经在 ALU 里做了，可以直接用 exmem_ex_res
                mem_stage_wdata = exmem_ex_res;
            end

            `WB_TIMER: begin
                // 计时器以后接 CSR/timer 模块
                mem_stage_wdata = exmem_timer_data;
            end

            `WB_CSR: begin
                // CSR 以后接 CSR 模块
                mem_stage_wdata = exmem_csr_rdata;
            end

            default: begin
                mem_stage_wdata = exmem_ex_res;
            end
        endcase
    end

    reg [31:0] fp_mem_stage_wdata;

    always @(*) begin
        case (exmem_FPWB_Sel)
            `FPWB_MEM: begin
                // fld.s
                fp_mem_stage_wdata = lsu_load_data;
            end

            `FPWB_GPR: begin
                // movgr2fr.w
                fp_mem_stage_wdata = exmem_gp_to_fp_data;
            end

            `FPWB_FPU: begin
                // fadd.s/fsub.s/fmul.s/fmov.s
                fp_mem_stage_wdata = exmem_ex_res;
            end

            default: begin
                fp_mem_stage_wdata = exmem_ex_res;
            end
        endcase
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            llbit  <= 1'b0;
            lladdr <= 32'b0;
        end
        else if (exc_commit || ertn_commit) begin
            llbit <= 1'b0;
        end
        else if (mem_can_commit) begin
            if (exmem_isll) begin
                llbit  <= 1'b1;
                lladdr <= exmem_ex_res;
            end
            else if (exmem_issc) begin
                llbit <= 1'b0;
            end
            else if (exmem_MemWr) begin
                // 单核简化：普通 store 后也清 LLbit，更保守
                llbit <= 1'b0;
            end
        end
    end


    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            memwb_valid <= 1'd0;
            memwb_regWr <= 1'd0;
            memwb_waddr <= 5'd0;
            memwb_wdata <= 32'd0;

            memwb_FpRegWr   <= 1'b0;
            memwb_fp_waddr  <= 5'b0;
            memwb_fp_wdata  <= 32'b0;
        end
        else if (mem_stall) begin
            memwb_valid <= 1'd0;
            memwb_regWr <= 1'd0;
            memwb_waddr <= 5'd0;
            memwb_wdata <= 32'd0;

            memwb_FpRegWr   <= 1'b0;
            memwb_fp_waddr  <= 5'b0;
            memwb_fp_wdata  <= 32'b0;
        end
        else begin
            memwb_valid <= mem_can_commit;
            memwb_regWr <= mem_can_commit && exmem_regWr;
            memwb_waddr <= exmem_regwaddr;
            memwb_wdata <= mem_stage_wdata;

            memwb_FpRegWr  <= mem_can_commit && exmem_FpRegWr;
            memwb_fp_waddr <= exmem_fp_waddr;
            memwb_fp_wdata <= fp_stage_wdata;
        end
    end

    assign test_pc_cur =
        ifid_valid ? ifid_pc :
        if_valid   ? if_pc   :
                    32'b0;

    assign test_inst =
        ifid_valid ? ifid_inst :
        if_valid   ? if_inst   :
                    32'b0;

    
endmodule

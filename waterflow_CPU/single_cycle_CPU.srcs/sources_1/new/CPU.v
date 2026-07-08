`include "CPU_def.vh"
module read_Instr(
    input        clk,
    input        rst,
    input        branch,
    input        stall,
    input [31:0] branch_target,
    output[31:0] pc_cur,
    output[31:0] instr,
    output[31:0] nxt_pc
    );
    
    reg[31:0]  pc;
    wire[31:0] next_pc;
    
    always @(posedge clk or negedge rst) begin
        if(!rst)          pc <= 32'h1C000000;
        else if(!stall)   pc <= next_pc;
    end
    
    Instr_rom IR(.addr(pc[17:2]),.data(instr));
    
    adder instr_add(
        .A  (pc),
        .B  (32'd4),
        .cin(1'b0),
        .Sum(nxt_pc),
        .cout()
    );
    
    assign next_pc = branch ? branch_target : nxt_pc;
    assign pc_cur  = pc;
    
endmodule

module Control_Unit(
    input     [31:0] inst,
    output           regWr,
    output reg[3:0]  branch,
    output           RegDst,
    output           RegDst1,
    output reg[4:0]  ALUctr,
    output           ALUSrc1,
    output reg[1:0]  ALUSrc2,
    output           Src1Used,
    output           Src2Used,
    output reg[3:0]  ImmType,

    output           MemWr,
    output           MemRd,
    output           MemEn,
    output reg[1:0]  MemSz,
    output           MemSel,
    output           MemZeroExt,

    output    [2:0]  alsl_shift,

    output reg[1:0]  UnitSel,
    output reg[2:0]  MDUctr,

    output           need_priv,
    output           inst_valid,
    output           fp_inst,
    output           trap_sys,
    output           trap_brk,
    output           rdtime_inst,


    output           csr_en,
    output           csr_we,
    output reg [1:0] csr_op,
    output [13:0]    csr_num,
    output reg[2:0]  specop,
    
    
    output           FpRegWr,
    output reg[3:0]  FPUctr,
    output           FptoGpr,
    output           GprtoFp,
    output           FpSrc2,
    output           FpSrc1Used,
    output           FpSrc2Used,

    output reg[3:0]  WB_Sel,
    output reg[1:0]  FPWB_Sel,

    output           issc,
    output           isll
    
    );
    
    wire nop    = (inst        == 32'h03400000);
    wire add_w  = (inst[31:15] == 17'h00020);
    wire sub_w  = (inst[31:15] == 17'h00022);
    wire nor_   = (inst[31:15] == 17'h00028);
    wire and_   = (inst[31:15] == 17'h00029);
    wire or_    = (inst[31:15] == 17'h0002A);
    wire xor_   = (inst[31:15] == 17'h0002B);
    wire slt    = (inst[31:15] == 17'h00024);
    wire sltu   = (inst[31:15] == 17'h00025);
    wire andn   = (inst[31:15] == 17'h0002C);//rk与rj的按位与取反
    wire orn    = (inst[31:15] == 17'h0002D);//rk与rj的按位或取反
    wire sll_w  = (inst[31:15] == 17'h0002E);
    wire srl_w  = (inst[31:15] == 17'h0002F);
    wire sra_w  = (inst[31:15] == 17'h00030);
    wire mul_w  = (inst[31:15] == 17'h00038);
    wire mulh_w = (inst[31:15] == 17'h00039);//
    wire mulh_wu= (inst[31:15] == 17'h0003A);//
    wire div_w  = (inst[31:15] == 17'h00040);//
    wire mod_w  = (inst[31:15] == 17'h00041);//
    wire div_wu = (inst[31:15] == 17'h00042);//
    wire mod_wu = (inst[31:15] == 17'h00043);//
    
    wire slli_w = (inst[31:15] == 17'h00081);
    wire srli_w = (inst[31:15] == 17'h00089);
    wire srai_w = (inst[31:15] == 17'h00091);
    
    wire ext_w_h= (inst[31:15] == 17'h00002);//rj[15:0]符号扩展�??32�??
    wire ext_w_b= (inst[31:15] == 17'h00003);//rj[7:0]符号扩展�??32�??
    wire clz_w  = (inst[31:15] == 17'h00004);//rj从高位开始连�??0的个�??
    wire ctz_w  = (inst[31:15] == 17'h00005);//rj从低位开始连�??0的个�??
    wire clo_w  = (inst[31:15] == 17'h00006);//rj从高位开始连�??1的个�??
    wire cto_w  = (inst[31:15] == 17'h00007);//rj从低位开始连�??1的个�??

    wire cpucfg = (inst[31:15] == 17'h0000b);//读CPU配置寄存�??

    wire maskeqz= (inst[31:15] == 17'h00070);//如果rk==0�??0，否则写rj
    wire masknez= (inst[31:15] == 17'h00071);//如果rk!=0�??0，否则写rj

    wire break_ = (inst[31:15] == 17'h00054);//断点异常
    wire syscall= (inst[31:15] == 17'h00056);//系统调用，触发系统异�??

    wire ertn   = (inst        == 32'h0648_3800);//返回异常处理程序

    wire dbar   = (inst[31:15] == 17'h070e4);//数据访问屏障
    wire ibar   = (inst[31:15] == 17'h070e5);//指令访问屏障
    wire idle   = (inst[31:15] == 17'h00c91);//等待中断
    wire cacop  = (inst[31:22] == 10'h018);//cache操作指令

    wire ll_w   = (inst[31:24] == 8'h20);//读内�??+记录地址+设置llbit
    wire sc_w   = (inst[31:24] == 8'h21);//判断llbit，如果是1就写内存并且rd�??1，否则rd�??0不写内存

    wire csrrd  = (inst[31:24] == 8'h04) && (inst[9:5] == 5'h0);//从CSR寄存器中读数据到通用寄存�??
    wire csrwr  = (inst[31:24] == 8'h04) && (inst[9:5] == 5'h1);//将rd数据写入CSR寄存�??

    wire csrxchg= (inst[31:24] == 8'h04) && (inst[9:5] != 5'd0) && (inst[9:5] != 5'd1);//按rj掩码把rd数据写入CSR寄存器，并将CSR寄存器原来的值写入rd
    
    wire rdtimel_w=(inst[31:15]==17'h00000)&&(inst[14:10]==5'h18);//�??64位计时器�??32�??
    wire rdtimeh_w=(inst[31:15]==17'h00000)&&(inst[14:10]==5'h19);//�??64位计时器�??32�??
    
    

    wire alsl_w = (inst[31:17] == 15'h0002);//把rj左移sa2位后加rk
    
    
    wire fadd_s = (inst[31:15] == 17'h00201);//
    wire fsub_s = (inst[31:15] == 17'h00205);//
    wire fmul_s = (inst[31:15] == 17'h00209);//
    
    wire fmov_s     = (inst[31:10] == 22'h004525);//
    wire movgr2fr_w = (inst[31:10] == 22'h004529);//
    wire movfr2gr_s = (inst[31:10] == 22'h00452d);//
    
    wire fld_s  = (inst[31:22] == 10'h0ac);//
    wire fst_s  = (inst[31:22] == 10'h0ad);//
    
    wire bstrins_w = (inst[31:22] == 10'h006); //未实�??
    wire bstrpick_w= (inst[31:22] == 10'h007); //未实�??
    wire slti   = (inst[31:22] == 10'h008);//
    wire sltui  = (inst[31:22] == 10'h009);//

    wire addi_w = (inst[31:22] == 10'h00a);
    wire andi   = (inst[31:22] == 10'h00d);//
    wire ori    = (inst[31:22] == 10'h00e);//
    wire xori   = (inst[31:22] == 10'h00f);//
    wire ld_b   = (inst[31:22] == 10'h0a0);//
    wire ld_h   = (inst[31:22] == 10'h0a1);//
    wire ld_w   = (inst[31:22] == 10'h0a2);
    wire st_b   = (inst[31:22] == 10'h0a4);//
    wire st_h   = (inst[31:22] == 10'h0a5);//
    wire st_w   = (inst[31:22] == 10'h0a6);
    wire ld_bu  = (inst[31:22] == 10'h0a8);//
    wire ld_hu  = (inst[31:22] == 10'h0a9);//
    
    
    wire lu12i_w= (inst[31:25] == 7'h0a);
    wire pcaddi = (inst[31:25] == 7'h0c);//计算PC值加上（20位立即数左移2位）
    wire pcalau12i=(inst[31:25] == 7'h0d);//计算PC值加�??20位立即数，取�??4�??
    wire pcaddu12i=(inst[31:25] == 7'h0e);//计算PC值加上（20位立即数左移12位）
    
    wire beqz   = (inst[31:26] == 6'h10);
    wire bnez   = (inst[31:26] == 6'h11);
    wire jirl   = (inst[31:26] == 6'h13);
    wire b      = (inst[31:26] == 6'h14);
    wire bl     = (inst[31:26] == 6'h15);
    wire beq    = (inst[31:26] == 6'h16);
    wire bne    = (inst[31:26] == 6'h17);
    wire blt    = (inst[31:26] == 6'h18);
    wire bge    = (inst[31:26] == 6'h19);//有符号大于等于跳�??
    wire bltu   = (inst[31:26] == 6'h1a);//无符号小于跳�??
    wire bgeu   = (inst[31:26] == 6'h1b);

    
    
    wire r_type = add_w | sub_w | mul_w | and_ | nor_ | xor_ | or_ | slt | sltu | sll_w | srl_w | sra_w | andn | orn | mulh_w | mulh_wu | div_w | mod_w | div_wu | mod_wu | alsl_w | maskeqz | masknez ;
    
    wire load_gpr  = ld_b | ld_h | ld_w | ld_bu | ld_hu | ll_w;
    wire store_gpr = st_b | st_h | st_w | sc_w;

    wire load_fp   = fld_s;
    wire store_fp  = fst_s;

    wire br_2src = beq | bne | blt | bge | bltu | bgeu;
    wire br_1src = beqz | bnez;
    wire br_uncond = b | bl | jirl;

    wire imm_alu = addi_w | slti | sltui | andi | ori | xori
                | slli_w | srli_w | srai_w | lu12i_w;

    wire pc_alu  = pcaddi | pcaddu12i | pcalau12i;

    wire one_src_alu = ext_w_h | ext_w_b | clz_w | ctz_w | clo_w | cto_w | cpucfg;

    wire csr_inst = csrrd | csrwr | csrxchg;
    wire timer_inst = rdtimel_w | rdtimeh_w;

    assign fp_inst = fadd_s | fsub_s | fmul_s | fmov_s
                | movgr2fr_w | movfr2gr_s
                | fld_s | fst_s;

    assign need_priv = csr_inst | ertn | idle | cacop;

    wire valid_alu_inst = nop
                        | r_type
                        | addi_w | slti | sltui | andi | ori | xori
                        | slli_w | srli_w | srai_w
                        | ext_w_h | ext_w_b | clz_w | ctz_w | clo_w | cto_w
                        | lu12i_w | pcaddi | pcaddu12i | pcalau12i
                        | cpucfg;

    wire valid_mem_inst = ld_b | ld_h | ld_w | ld_bu | ld_hu
                        | st_b | st_h | st_w
                        | ll_w | sc_w
                        | fld_s | fst_s;

    wire valid_branch_inst = beq | bne | blt | bge | bltu | bgeu
                            | beqz | bnez | b | bl | jirl;

    wire valid_special_inst = syscall | break_ | ertn
                            | dbar | ibar | idle | cacop
                            | csr_inst | timer_inst;

    assign inst_valid = valid_alu_inst
                    | valid_mem_inst
                    | valid_branch_inst
                    | fp_inst
                    | valid_special_inst;
    
    
    assign regWr    =   // 3R / 2R / 普�?? ALU �?? GPR
                        r_type
                        | addi_w | slti | sltui | andi | ori | xori
                        | slli_w | srli_w | srai_w
                        | lu12i_w
                        | ext_w_h | ext_w_b | clz_w | ctz_w | clo_w | cto_w
                        | pcaddi | pcaddu12i | pcalau12i
                        | cpucfg
                        | rdtimel_w | rdtimeh_w

                        // load 类写 GPR
                        | ld_b | ld_h | ld_w | ld_bu | ld_hu | ll_w

                        // sc.w 要写 rd = 成功/失败标志
                        | sc_w

                        // 跳转链接�?? GPR
                        | bl | jirl

                        // CSR 指令会把 CSR 旧�?�写 rd
                        | csrrd | csrwr | csrxchg

                        // 浮点转�?�用寄存�??
                        | movfr2gr_s;

    assign RegDst   = store_gpr | beq | bne | blt | bge | bltu | bgeu | csrwr | csrxchg;
    assign RegDst1  = bl;
    assign ALUSrc1  = bl | jirl | pcaddi | pcaddu12i | pcalau12i;
    assign MemWr    = st_b|st_h|st_w|fst_s;
    assign MemRd    = ld_b|ld_h|ld_w|ld_bu|ld_hu|ll_w|fld_s;
    assign MemEn    = MemWr | MemRd | issc;
    assign MemZeroExt=ld_bu|ld_hu;
    assign trap_sys  = syscall;
    assign trap_brk  = break_;
    assign rdtime_inst = rdtimel_w | rdtimeh_w;

    assign Src1Used = r_type
                    | addi_w | slti | sltui | andi | ori | xori
                    | slli_w | srli_w | srai_w
                    | ext_w_h | ext_w_b | clz_w | ctz_w | clo_w | cto_w
                    | load_gpr | store_gpr
                    | load_fp | store_fp
                    | br_1src | br_2src | jirl
                    | cpucfg
                    | csrxchg
                    | movgr2fr_w
                    | cacop;

    assign Src2Used = r_type
                    | store_gpr
                    | br_2src
                    | csrwr
                    | csrxchg;

    assign alsl_shift = {1'b0,inst[16:15]}+3'd1;
    
    assign isll = ll_w;
    assign issc = sc_w;
    
    assign FpRegWr    = fadd_s | fsub_s | fmul_s | fmov_s | movgr2fr_w | fld_s ;
    assign FptoGpr    = movfr2gr_s ;
    assign GprtoFp    = movgr2fr_w ;
    assign FpSrc1Used = fadd_s | fsub_s | fmul_s | fmov_s | movfr2gr_s ;
    assign FpSrc2Used = fadd_s | fsub_s | fmul_s | fst_s ;
    assign FpSrc2      = fst_s;

    assign MemSel     = fst_s;

    assign csr_en  = csrrd | csrwr | csrxchg;
    assign csr_we  = csrwr | csrxchg;
    assign csr_num = inst[23:10];

    always @(*) begin
        case (1'b1)
            csrrd:   csr_op = `CSR_RD;
            csrwr:   csr_op = `CSR_WR;
            csrxchg: csr_op = `CSR_XCHG;
            default: csr_op = `CSR_RD;
        endcase
    end

    always @(*) begin
        case(1'b1)
            // ALU 第二操作数来自立即数
            addi_w, slti, sltui, andi, ori, xori,
            slli_w, srli_w, srai_w,
            lu12i_w,
            ld_b, ld_h, ld_w, ld_bu, ld_hu,
            st_b, st_h, st_w,
            fld_s, fst_s,
            ll_w, sc_w,
            pcaddi, pcaddu12i, pcalau12i,
            cacop:
                ALUSrc2 = 2'b01;

            // PC + 4
            bl, jirl:
                ALUSrc2 = 2'b10;

            // rk
            default:
            ALUSrc2 = 2'b00;
        endcase
    end

    always @(*) begin
        case(1'b1)
            mul_w, mulh_w, mulh_wu, div_w, mod_w, div_wu, mod_wu:
                UnitSel = `MDU_use;
            fadd_s, fsub_s, fmul_s, fmov_s:
                UnitSel = `FPU_use;
            default:
                UnitSel = `ALU_use;
        endcase
    end

    always @(*) begin
        case(1'b1)
            ld_b | ld_bu | st_b: MemSz = 2'b00;
            ld_h | ld_hu | st_h: MemSz = 2'b01;
            ld_w | st_w  | fst_s | fld_s | ll_w | sc_w :MemSz = 2'b10;
            default:             MemSz = 2'b10;
        endcase
    end
    
    always @(*) begin
        case(1'b1)
            nop  :   ALUctr = `ALU_NOP;

            add_w,
            addi_w,
            ld_b, ld_h, ld_w, ld_bu, ld_hu,
            st_b, st_h, st_w,
            fld_s, fst_s,
            ll_w, sc_w,
            bl, jirl,
            pcaddi,
            pcaddu12i,
            cacop:
                ALUctr = `ALU_ADD ;
            
            sub_w,
            beq, bne, blt, bge, bltu, bgeu:
                ALUctr = `ALU_SUB;

            and_, andi:      ALUctr = `ALU_AND;
            or_, ori:        ALUctr = `ALU_OR;
            xor_, xori:      ALUctr = `ALU_XOR;
            nor_:            ALUctr = `ALU_NOR;

            slt, slti:       ALUctr = `ALU_SLT;
            sltu, sltui:     ALUctr = `ALU_SLTU;

            sll_w, slli_w:   ALUctr = `ALU_SLL;
            srl_w, srli_w:   ALUctr = `ALU_SRL;
            sra_w, srai_w:   ALUctr = `ALU_SRA;

            lu12i_w:         ALUctr = `ALU_LU12I;

            ext_w_h:         ALUctr = `ALU_EXT_H;
            ext_w_b:         ALUctr = `ALU_EXT_B;
            clz_w:           ALUctr = `ALU_CLZ;
            ctz_w:           ALUctr = `ALU_CTZ;
            clo_w:           ALUctr = `ALU_CLO;
            cto_w:           ALUctr = `ALU_CTO;

            andn:            ALUctr = `ALU_ANDN;
            orn:             ALUctr = `ALU_ORN;

            alsl_w:          ALUctr = `ALU_ALSL;
            maskeqz:         ALUctr = `ALU_MASKEQZ;
            masknez:         ALUctr = `ALU_MASKNEZ;

            pcalau12i:       ALUctr = `ALU_PCALAU;
            cpucfg:          ALUctr = `ALU_CPUCFG;

            default:         ALUctr = `ALU_NOP;
        endcase
    end
    
    always @(*) begin
        case(1'b1)
            fadd_s:  FPUctr = `FP_adds;
            fsub_s:  FPUctr = `FP_subs;
            fmul_s:  FPUctr = `FP_muls;
            fmov_s:  FPUctr = `FP_movs;
            default: FPUctr = `FP_none;
        endcase
    end
    
    always @(*) begin
        case(1'b1)
            bne:     branch = `BR_BNE;
            blt:     branch = `BR_BLT;
            b  :     branch = `BR_B;
            bl :     branch = `BR_B;
            jirl:    branch = `BR_JIRL;
            beqz:    branch = `BR_BEQZ;
            bgeu:    branch = `BR_BGEU;
            beq :    branch = `BR_BEQ;
            bge :    branch = `BR_BGE;
            bltu:    branch = `BR_BLTU;
            bnez:    branch = `BR_BNEZ;
            default: branch = `BR_NONE;
        endcase
    end

    always @(*) begin
        case(1'b1)
            ld_b, ld_h, ld_w, ld_bu, ld_hu, ll_w: WB_Sel = `WB_MEM;
            sc_w: WB_Sel = `WB_SC;
            bl,jirl: WB_Sel = `WB_PC4;
            csrrd, csrwr, csrxchg: WB_Sel = `WB_CSR;
            cpucfg: WB_Sel = `WB_CPUCFG;
            rdtimel_w, rdtimeh_w: WB_Sel = `WB_TIMER;
            movfr2gr_s: WB_Sel = `WB_FPR;
            mul_w, mulh_w, mulh_wu, div_w, mod_w, div_wu, mod_wu: WB_Sel = `WB_MDU;
            default: WB_Sel = `WB_ALU;
        endcase
    end

    always @(*) begin
        case(1'b1)
            mul_w:      MDUctr = `MDU_MULW;
            mulh_w:     MDUctr = `MDU_MULHW;
            mulh_wu:    MDUctr = `MDU_MULHWU;
            div_w:      MDUctr = `MDU_DIVW;
            mod_w:      MDUctr = `MDU_MODW;
            div_wu:     MDUctr = `MDU_DIVWU;
            mod_wu:     MDUctr = `MDU_MODWU;
            default:    MDUctr = `MDU_NONE;
        endcase
    end

    always @(*) begin
        case(1'b1)
            fld_s: FPWB_Sel = `FPWB_MEM;
            movgr2fr_w: FPWB_Sel = `FPWB_GPR;
            default: FPWB_Sel = `FPWB_FPU;
        endcase
    end
    

    always @(*) begin
        case (1'b1)
            ertn:    specop = `SP_ERTN;
            dbar:    specop = `SP_DBAR;
            ibar:    specop = `SP_IBAR;
            idle:    specop = `SP_IDLE;
            cacop:   specop = `SP_CACOP;
            default: specop = `SP_NONE;
        endcase
    end

    always @(*) begin
        case (1'b1)
            addi_w, slti, sltui,
            ld_b, ld_h, ld_w, ld_bu, ld_hu,
            st_b, st_h, st_w,
            fld_s, fst_s, cacop:
                ImmType = `IMM_SI12;

            andi, ori, xori:
                ImmType = `IMM_UI12;

            slli_w, srli_w, srai_w:
                ImmType = `IMM_UI5;

            lu12i_w, pcaddu12i, pcalau12i:
                ImmType = `IMM_SI20_LSL12;

            pcaddi:
                ImmType = `IMM_SI20_LSL2;

            ll_w, sc_w:
                ImmType = `IMM_SI14_LSL2;

            jirl,beq,bne,blt,bge,bltu,bgeu:
                ImmType = `IMM_SI16_LSL2;
            
            beqz,bnez:
                ImmType = `IMM_SI21_LSL2;

            b,bl:
                ImmType = `IMM_SI26_LSL2;

            default:
                ImmType = `IMM_NONE;
        endcase
    end

endmodule

module ImmGen(
    input     [31:0] inst,
    input     [3:0] ImmType,
    output reg[31:0] imm32
);
    
    wire [4:0]  ui5    = inst[14:10];
    wire [11:0] imm12  = inst[21:10];
    wire [13:0] imm14  = inst[23:10];
    wire [15:0] imm16  = inst[25:10];
    wire [19:0] imm20  = inst[24:5];
    wire [20:0] offs21 = {inst[4:0], inst[25:10]};
    wire [25:0] offs26 = {inst[9:0], inst[25:10]};
    
    always @(*) begin
        case(ImmType)
            `IMM_UI5:          imm32 = {27'b0, ui5};
            `IMM_SI12:         imm32 = {{20{imm12[11]}}, imm12};
            `IMM_UI12:         imm32 = {20'b0, imm12};
            `IMM_SI14_LSL2:    imm32 = {{16{imm14[13]}}, imm14, 2'b00};
            `IMM_SI16_LSL2:    imm32 = {{14{imm16[15]}}, imm16, 2'b00};
            `IMM_SI20_LSL2:    imm32 = {{10{imm20[19]}}, imm20, 2'b00};
            `IMM_SI20_LSL12:   imm32 = {imm20, 12'b0};
            `IMM_SI21_LSL2:    imm32 = {{9{offs21[20]}}, offs21, 2'b00};
            `IMM_SI26_LSL2:    imm32 = {{4{offs26[25]}}, offs26, 2'b00};
            default:           imm32 = 32'd0;  
        endcase
    end 
endmodule

module EXU(
    input         clk,
    input         rst,

    input  [31:0] pc,
    input  [31:0] rdata1,
    input  [31:0] rdata2,
    input  [31:0] imm32,

    input         flush,
    input         ex_valid,
    input         exmem_ready,

    input  [31:0] fp_rdata1,
    input  [31:0] fp_rdata2,

    input  [3:0]  branch,

    input         ALUSrc1,
    input  [1:0]  ALUSrc2,
    input  [2:0]  alsl_shift,

    input  [1:0]  UnitSel,
    input  [2:0]  MDUctr,
    input  [3:0]  FPUctr,
    input  [4:0]  ALUctr,

    output        ex_busy,
    output        ex_ready,
    output        ex_res_valid,

    output reg [31:0] ex_res,
    output     [31:0] fp_to_gp_data,
    output     [31:0] gp_to_fp_data,

    output     [31:0] branch_target,
    output            take_branch
);

    reg [31:0] op_b;

    wire [31:0] op_a = ALUSrc1 ? pc : rdata1;

    wire [31:0] alu_res;
    wire [31:0] mdu_res;
    wire [31:0] fpu_res;

    wire mdu_ready;
    wire fpu_ready;
    wire mdu_busy;
    wire fpu_busy;

    assign fp_to_gp_data = fp_rdata1;
    assign gp_to_fp_data = rdata1;

    always @(*) begin
        case (ALUSrc2)
            2'b00:   op_b = rdata2;
            2'b01:   op_b = imm32;
            2'b10:   op_b = 32'd4;
            default: op_b = rdata2;
        endcase
    end

    ALU u_alu(
        .A(op_a),
        .B(op_b),
        .alsl_shift(alsl_shift),
        .alu_op(ALUctr),
        .alu_res(alu_res)
    );

    wire is_mdu_inst = ex_valid && (UnitSel == `MDU_use);
    wire is_fpu_inst = ex_valid && (UnitSel == `FPU_use) && (FPUctr != `FP_movs);
    wire is_multi    = is_mdu_inst || is_fpu_inst;

    reg        multi_busy;
    reg        multi_done_hold;
    reg        multi_is_mdu;
    reg        multi_is_fpu;
    reg [31:0] multi_result_hold;

    wire start_multi = ex_valid && is_multi && !multi_busy && !multi_done_hold;
    wire mdu_start   = start_multi && is_mdu_inst;
    wire fpu_start   = start_multi && is_fpu_inst;

    assign ex_ready     = !ex_valid || !is_multi || multi_done_hold;
    assign ex_busy      = ex_valid && is_multi && !multi_done_hold;
    assign ex_res_valid = ex_valid && ex_ready;

    wire result_accepted = ex_res_valid && exmem_ready;

    FPU u_fpu(
        .clk(clk),
        .rst(rst),
        .en(fpu_start),
        .A(fp_rdata1),
        .B(fp_rdata2),
        .fpu_op(FPUctr),
        .ready(fpu_ready),
        .busy(fpu_busy),
        .fpu_res(fpu_res)
    );

    MDU u_mdu(
        .clk(clk),
        .rst(rst),
        .en(mdu_start),
        .A(rdata1),
        .B(rdata2),
        .mdu_op(MDUctr),
        .ready(mdu_ready),
        .busy(mdu_busy),
        .mdu_res(mdu_res)
    );

    always @(posedge clk or negedge rst) begin
        if (!rst || flush) begin
            multi_busy        <= 1'b0;
            multi_done_hold   <= 1'b0;
            multi_is_mdu      <= 1'b0;
            multi_is_fpu      <= 1'b0;
            multi_result_hold <= 32'b0;
        end
        else begin
            if (start_multi) begin
                multi_busy      <= 1'b1;
                multi_done_hold <= 1'b0;
                multi_is_mdu    <= is_mdu_inst;
                multi_is_fpu    <= is_fpu_inst;
            end

            if (multi_busy && multi_is_mdu && mdu_ready) begin
                multi_busy        <= 1'b0;
                multi_done_hold   <= 1'b1;
                multi_result_hold <= mdu_res;
            end

            if (multi_busy && multi_is_fpu && fpu_ready) begin
                multi_busy        <= 1'b0;
                multi_done_hold   <= 1'b1;
                multi_result_hold <= fpu_res;
            end

            if (result_accepted) begin
                multi_done_hold <= 1'b0;
            end
        end
    end

    always @(*) begin
        case (UnitSel)
            `MDU_use: begin
                ex_res = multi_done_hold ? multi_result_hold : mdu_res;
            end

            `FPU_use: begin
                if (FPUctr == `FP_movs)
                    ex_res = fp_rdata1;
                else
                    ex_res = multi_done_hold ? multi_result_hold : fpu_res;
            end

            default: begin
                ex_res = alu_res;
            end
        endcase
    end

    BRU u_bru(
        .pc(pc),
        .imm32(imm32),
        .branch(branch),
        .rdata1(rdata1),
        .rdata2(rdata2),
        .branch_target(branch_target),
        .take_branch(take_branch)
    );

endmodule

module BPU(
    input             clk,
    input             rst,

    input      [31:0] if_pc,
    input      [31:0] if_inst,

    output reg        pred_taken,
    output reg [31:0] pred_target,

    input             update_valid,
    input      [31:0] update_pc,
    input             update_taken,
    input      [31:0] update_target,
    input             update_is_cond,
    input             update_is_jirl
    );

    localparam INDEX_BITS = 8;
    localparam ENTRY_NUM  = 256;
    localparam TAG_WIDTH  = 32-INDEX_BITS-2;

    wire [INDEX_BITS-1:0] if_idx = if_pc[INDEX_BITS+1:2];
    wire [TAG_WIDTH-1 :0] if_tag = if_pc[31:INDEX_BITS+2];

    wire [INDEX_BITS-1:0] upd_idx = update_pc[INDEX_BITS+1:2];
    wire [TAG_WIDTH-1 :0] upd_tag = update_pc[31:INDEX_BITS+2];

    reg  [1:0]            bht        [0:ENTRY_NUM-1];

    reg                   btb_valid  [0:ENTRY_NUM-1];
    reg  [TAG_WIDTH-1:0]  btb_tag    [0:ENTRY_NUM-1];
    reg  [31:0]           btb_target [0:ENTRY_NUM-1];


    wire beqz  = (if_inst[31:26] == 6'h10);
    wire bnez  = (if_inst[31:26] == 6'h11);
    wire jirl  = (if_inst[31:26] == 6'h13);
    wire b     = (if_inst[31:26] == 6'h14);
    wire bl    = (if_inst[31:26] == 6'h15);
    wire beq   = (if_inst[31:26] == 6'h16);
    wire bne   = (if_inst[31:26] == 6'h17);
    wire blt   = (if_inst[31:26] == 6'h18);
    wire bge   = (if_inst[31:26] == 6'h19);
    wire bltu  = (if_inst[31:26] == 6'h1a);
    wire bgeu  = (if_inst[31:26] == 6'h1b);

    wire is_cond =  beqz | bnez |
                    beq  | bne  |
                    blt  | bge  |
                    bltu | bgeu;
    
    wire is_uncond = b | bl;
    wire is_jirl =  jirl;
    wire is_branch = is_cond | is_uncond | is_jirl;

    wire [15:0] imm16  = if_inst[25:10];
    wire [20:0] offs21 = {if_inst[4:0], if_inst[25:10]};
    wire [25:0] offs26 = {if_inst[9:0], if_inst[25:10]};

    wire [31:0] target_16 = if_pc + {{14{imm16[15]}},  imm16,  2'b00};
    wire [31:0] target_21 = if_pc + {{9{offs21[20]}}, offs21, 2'b00};
    wire [31:0] target_26 = if_pc + {{4{offs26[25]}}, offs26, 2'b00};

    wire btb_hit = btb_valid[if_idx] && (btb_tag[if_idx] == if_tag);

    wire bht_taken = bht[if_idx][1];

    always @(*) begin
        if(is_uncond)    pred_taken = 1'b1;
        else if(is_jirl) pred_taken = btb_hit;
        else if(is_cond) pred_taken = bht_taken;
        else             pred_taken = 1'b0;
    end

    always @(*) begin
        if(is_uncond)               pred_target = target_26;
        else if(beqz | bnez)        pred_target = target_21;
        else if(is_cond)            pred_target = target_16;
        else if(is_jirl && btb_hit) pred_target = btb_target[if_idx];
        else                        pred_target = if_pc + 32'd4;
    end

    integer i;

    always @(posedge clk or negedge rst) begin
        if(!rst) begin
            for(i = 0; i<ENTRY_NUM; i = i + 1) begin
                bht[i]        <= 2'b01;
                btb_valid[i]  <= 1'b0;
                btb_tag[i]    <= {TAG_WIDTH{1'b0}};
                btb_target[i] <= 32'b0;
            end
        end
        else begin
            if (update_valid && update_is_cond) begin
                if (update_taken) begin
                    if (bht[upd_idx] != 2'b11)
                        bht[upd_idx] <= bht[upd_idx] + 2'b01;
                end
                else begin
                    if (bht[upd_idx] != 2'b00)
                        bht[upd_idx] <= bht[upd_idx] - 2'b01;
                end
            end
            if (update_valid && update_is_jirl && update_taken) begin
                btb_valid[upd_idx]  <= 1'b1;
                btb_tag[upd_idx]    <= upd_tag;
                btb_target[upd_idx] <= update_target;
            end
        end
    end


endmodule

module CPU(
    input        clk,
    input        rst,
    input [4:0]  test_addr,
    output[31:0] test_data,
    output[31:0] test_pc_cur,
    output[31:0] test_inst,
    
    output       bus_req,
    output       bus_we,
    output[31:0] bus_addr,
    output[31:0] bus_wdata,
    
    input[31:0]  bus_rdata,
    input        bus_ready
);
    
    wire[31:0] pc_cur;
    wire[31:0] nxt_pc;
    wire[31:0] branch_target;
    wire[31:0] inst;
    wire[31:0] imm32;
    
    wire       regWr;
    wire[2:0]  branch;
    wire       RegDst;
    wire       RegDst1;
    wire[4:0]  ALUctr;
    wire       ALUSrc1;
    wire[1:0]  ALUSrc2;
    wire       MemWr;
    wire       MemtoReg;
    wire       PCtoReg;
    
    wire       take_branch;
    wire       cpu_stall;
    
    wire[31:0] alu_res;
    
    wire[31:0] mem_rdata;
    
    reg        ifid_valid;
    reg [31:0] ifid_pc;
    reg [31:0] ifid_pc4;
    reg [31:0] ifid_inst;
    
    wire[31:0] if_pc;
    wire[31:0] if_pc4;
    wire[31:0] if_inst;
    
    reg        idex_valid;
    reg [31:0] idex_pc;
    reg [31:0] idex_pc4;
    reg [31:0] idex_rdata1;
    reg [31:0] idex_rdata2;
    reg [31:0] idex_imm32;
    reg [4:0]  idex_waddr;
    reg        idex_regWr;
    reg [2:0]  idex_branch;
    reg [4:0]  idex_ALUctr;
    reg        idex_ALUSrc1;
    reg [1:0]  idex_ALUSrc2;
    reg        idex_MemWr;
    reg        idex_MemtoReg;
    reg        idex_PCtoReg;
    
    wire[31:0] ex_alu_res;
    wire[31:0] ex_branch_target;
    wire       ex_take_branch_raw;
    wire       ex_take_branch = idex_valid && ex_take_branch_raw;
    
    reg        exmem_valid;
    reg [31:0] exmem_alu_res;
    reg [31:0] exmem_rdata2;
    reg [31:0] exmem_pc4;
    reg [4:0]  exmem_waddr;
    reg        exmem_regWr;
    reg        exmem_MemWr;
    reg        exmem_MemtoReg;
    reg        exmem_PCtoReg;
    
    wire [31:0] id_inst = ifid_inst;
    wire [31:0] id_imm32;
    wire id_regWr;
    wire [2:0] id_branch;
    wire id_RegDst;
    wire id_RegDst1;
    wire [3:0] id_ALUctr;
    wire id_ALUSrc1;
    wire [1:0] id_ALUSrc2;
    wire id_MemWr;
    wire id_MemtoReg;
    wire id_Src1Used;
    wire id_Src2Used;
    
    wire [4:0] id_rs1 = id_inst[9:5];
    wire [4:0] id_rs2 = id_RegDst ? id_inst[4:0] : id_inst[14:10];
    wire [4:0] id_waddr = id_RegDst1 ? 5'd1 : id_inst[4:0];
    
    reg memwb_valid;
    reg [31:0] memwb_wdata;
    reg [4:0] memwb_waddr;
    reg memwb_regWr;
    
    wire id_src1_hazard_idex = id_Src1Used && idex_valid && idex_regWr && (idex_waddr != 5'd0) && (id_rs1 == idex_waddr);
    wire id_src2_hazard_idex = id_Src2Used && idex_valid && idex_regWr && (idex_waddr != 5'd0) && (id_rs2 == idex_waddr);
    wire id_src1_hazard_exmem = id_Src1Used && exmem_valid && exmem_regWr && (exmem_waddr != 5'd0) && (id_rs1 == exmem_waddr);
    wire id_src2_hazard_exmem = id_Src2Used && exmem_valid && exmem_regWr && (exmem_waddr != 5'd0) && (id_rs2 == exmem_waddr);
    wire id_src1_hazard_memwb = id_Src1Used && memwb_valid && memwb_regWr && (memwb_waddr != 5'd0) && (id_rs1 == memwb_waddr);
    wire id_src2_hazard_memwb = id_Src2Used && memwb_valid && memwb_regWr && (memwb_waddr != 5'd0) && (id_rs2 == memwb_waddr);
    
    wire raw_stall = ifid_valid & (id_src1_hazard_idex | id_src2_hazard_idex |id_src1_hazard_exmem | id_src2_hazard_exmem | id_src1_hazard_memwb | id_src2_hazard_memwb);
    
    assign test_pc_cur = ifid_valid ? ifid_pc : if_pc;
    assign test_inst   = ifid_valid ? ifid_inst : if_inst;
    assign cpu_stall   = (MemWr | MemtoReg) & (!bus_ready);
    
    
    
    assign bus_req     = exmem_valid & (exmem_MemWr | exmem_MemtoReg);
    assign bus_we      = exmem_MemWr;
    assign bus_addr    = exmem_alu_res;
    assign bus_wdata   = exmem_rdata2;
    
    wire mem_stall = bus_req & !bus_ready;
    assign mem_rdata   = bus_rdata;
    
    
    

    wire pc_stall = mem_stall | (raw_stall & !ex_take_branch);
    
    read_Instr u_rI(
        .clk(clk),
        .rst(rst),
        .pc_cur(if_pc),
        .branch(ex_take_branch & !mem_stall),
        .branch_target(ex_branch_target),
        .instr(if_inst),
        .nxt_pc(if_pc4),
        .stall(pc_stall)
    );
    
    
    
    wire flush_ifid = ex_take_branch & !mem_stall;
    
    always@(posedge clk or negedge rst)begin
        if(!rst) begin
            ifid_valid <= 1'b0;
            ifid_pc <= 32'b0;
            ifid_pc4 <= 32'b0;
            ifid_inst <= 32'b0;
        end
        else if(mem_stall) begin
            ifid_valid <= ifid_valid;
            ifid_pc <= ifid_pc;
            ifid_pc4 <= ifid_pc4;
            ifid_inst <= ifid_inst;
        end
        else if(flush_ifid) begin
            ifid_valid <= 1'b0;
            ifid_pc <= 32'b0;
            ifid_pc4 <= 32'b0;
            ifid_inst <= 32'b0;
        end
        else if(!raw_stall) begin
            ifid_valid <= 1'b1;
            ifid_pc <= if_pc;
            ifid_pc4 <= if_pc4;
            ifid_inst <= if_inst;
        end
    end
    
    
    
    Control_Unit u_ctrl(
        .inst(id_inst),
        .regWr(id_regWr),
        .branch(id_branch),
        .RegDst(id_RegDst),
        .RegDst1(id_RegDst1),
        .ALUctr(id_ALUctr),
        .ALUSrc1(id_ALUSrc1),
        .ALUSrc2(id_ALUSrc2),
        .MemWr(id_MemWr),
        .MemtoReg(id_MemtoReg),
        .Src1Used(id_Src1Used),
        .Src2Used(id_Src2Used)
    );
    
    ImmGen u_imm(
        .inst(id_inst),
        .imm32(id_imm32)
    );
    
    wire[31:0] id_rdata1;
    wire[31:0] id_rdata2;
    reg_32bit u_reg(
        .clk(clk),
        .rst(rst),
        .raddr1(id_rs1),
        .rdata1(id_rdata1),
        .raddr2(id_rs2),
        .rdata2(id_rdata2),
        .wen(memwb_valid & memwb_regWr),
        .waddr(memwb_waddr),
        .wdata(memwb_wdata),
        .test_addr(test_addr),
        .test_data(test_data)
    );
    
    
    
    
    
    wire flush_idex = (ex_take_branch & !mem_stall) | raw_stall;
    
    always@(posedge clk or negedge rst)begin
        if(!rst) begin
            idex_valid <= 1'b0;
            idex_regWr <= 1'b0;
            idex_MemWr <= 1'b0;
            idex_MemtoReg <= 1'b0;
            idex_branch <= 3'b000;
            idex_ALUctr <= 4'b0000;
            idex_ALUSrc1 <= 1'b0;
            idex_ALUSrc2 <= 1'b0;
            idex_pc <= 32'b0;
            idex_pc4 <= 32'b0;
            idex_rdata1 <= 32'b0;
            idex_rdata2 <= 32'b0;
            idex_imm32 <= 32'b0;
            idex_waddr <= 5'b0;
        end 
        else if(mem_stall) begin
            idex_valid <= idex_valid;
            idex_regWr <= idex_regWr;
            idex_MemWr <= idex_MemWr;
            idex_MemtoReg <= idex_MemtoReg;
            idex_branch <= idex_branch;
            idex_ALUctr <= idex_ALUctr;
            idex_ALUSrc1 <= idex_ALUSrc1;
            idex_ALUSrc2 <= idex_ALUSrc2;
            idex_pc <= idex_pc;
            idex_pc4 <= idex_pc4;
            idex_rdata1 <= idex_rdata1;
            idex_rdata2 <= idex_rdata2;
            idex_imm32 <= idex_imm32;
            idex_waddr <= idex_waddr;
        end 
        else if(flush_idex) begin
            idex_valid <= 1'b0;
            idex_regWr <= 1'b0;
            idex_MemWr <= 1'b0;
            idex_MemtoReg <= 1'b0;
            idex_PCtoReg <= 1'b0;
            idex_branch <= 3'b000;
        end
        else begin
            idex_valid <= ifid_valid;
            idex_pc <= ifid_pc;
            idex_pc4 <= ifid_pc4;
            idex_rdata1 <= id_rdata1;
            idex_rdata2 <= id_rdata2;
            idex_imm32 <= id_imm32;
            idex_waddr <= id_waddr;
            idex_regWr <= id_regWr;
            idex_branch <= id_branch;
            idex_ALUctr <= id_ALUctr;
            idex_ALUSrc1 <= id_ALUSrc1;
            idex_ALUSrc2 <= id_ALUSrc2;
            idex_MemWr <= id_MemWr;
            idex_MemtoReg <= id_MemtoReg;
        end
    end
    
    
    
    EXU u_exu(
        .pc(idex_pc),
        .rdata1(idex_rdata1),
        .rdata2(idex_rdata2),
        .imm32(idex_imm32),
        .branch(idex_branch),
        .ALUSrc1(idex_ALUSrc1),
        .ALUSrc2(idex_ALUSrc2),
        .ALUctr(idex_ALUctr),
        .alu_res(ex_alu_res),
        .branch_target(ex_branch_target),
        .take_branch(ex_take_branch_raw)
    );
    
    
    
    always @(posedge clk or negedge rst) begin
     if(!rst) begin
         exmem_valid <= 1'b0;
         exmem_regWr <= 1'b0;
         exmem_MemWr <= 1'b0;
         exmem_MemtoReg <= 1'b0;
         exmem_alu_res <= 32'b0;
         exmem_rdata2 <= 32'b0;
         exmem_pc4 <= 32'b0;
         exmem_waddr <= 5'b0;
     end else if(mem_stall) begin
         exmem_valid <= exmem_valid;
     end else begin
         exmem_valid <= idex_valid;
         exmem_alu_res <= ex_alu_res;
         exmem_rdata2 <= idex_rdata2;
         exmem_pc4 <= idex_pc4;
         exmem_waddr <= idex_waddr;
         exmem_regWr <= idex_regWr;
         exmem_MemWr <= idex_MemWr;
         exmem_MemtoReg <= idex_MemtoReg;
     end
end
    
    wire [31:0] mem_stage_wdata = exmem_MemtoReg ? bus_rdata : exmem_alu_res;
    always @(posedge clk or negedge rst) begin
         if(!rst) begin
             memwb_valid <= 1'b0;
             memwb_regWr <= 1'b0;
             memwb_waddr <= 5'b0;
             memwb_wdata <= 32'b0;
         end else if(mem_stall) begin
             memwb_valid <= memwb_valid;
         end else begin
             memwb_valid <= exmem_valid;
             memwb_regWr <= exmem_regWr;
             memwb_waddr <= exmem_waddr;
             memwb_wdata <= mem_stage_wdata;
         end
    end
    
endmodule

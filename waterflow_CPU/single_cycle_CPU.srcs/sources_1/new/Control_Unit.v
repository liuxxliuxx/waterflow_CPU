`include "CPU_def.vh"
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
    assign MemWr    = st_b|st_h|st_w|fst_s|sc_w;
    assign MemRd    = ld_b|ld_h|ld_w|ld_bu|ld_hu|ll_w|fld_s;
    assign MemEn    = MemWr | MemRd ;
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
`include "CPU_def.vh"

module IFU(
    input clk,
    input rst,

    input if_allowin,

    input         redirect_valid,
    input  [31:0] redirect_pc,

    input         pred_taken,
    input  [31:0] pred_target,

    output        if_valid,
    output [31:0] if_pc,
    output [31:0] if_pc4,
    output [31:0] if_inst,
    output        if_err,

    output        inst_req_valid,
    input         inst_req_ready,
    output [31:0] inst_req_vaddr,

    input         inst_resp_valid,
    input  [31:0] inst_resp_data,
    input         inst_resp_err
);
    reg [31:0] fetch_pc;
    reg        req_pending;
    reg [31:0] req_pc_hold;

    reg req_kill;
    reg out_valid;
    reg [31:0] out_pc;
    reg [31:0] out_inst;
    reg out_err;

    wire[31:0] out_pc4 = out_pc + 32'd4;

    wire out_fire = out_valid && if_allowin;

    wire[31:0] pred_next_pc = pred_taken ? pred_target : out_pc4;

    wire can_issue = !req_pending && (!out_valid || if_allowin);

    wire [31:0] issue_pc =
        redirect_valid ? redirect_pc :
        (out_valid && if_allowin) ? pred_next_pc : fetch_pc;

    assign inst_req_valid = can_issue;
    assign inst_req_vaddr = issue_pc;

    wire req_fire = inst_req_valid && inst_req_ready;

    assign if_valid = out_valid;
    assign if_pc    = out_pc;
    assign if_pc4   = out_pc4;
    assign if_inst  = out_inst;
    assign if_err   = out_err;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            fetch_pc    <= 32'h1C000000;

            req_pending <= 1'b0;
            req_pc_hold <= 32'b0;
            req_kill    <= 1'b0;

            out_valid   <= 1'b0;
            out_pc      <= 32'b0;
            out_inst    <= 32'b0;
            out_err     <= 1'b0;
        end
        else begin
            if (redirect_valid) begin
                fetch_pc  <= redirect_pc;
                out_valid <= 1'b0;
                out_pc    <= 32'b0;
                out_inst  <= 32'b0;
                out_err   <= 1'b0;

                if (req_pending) begin
                    req_kill <= 1'b1;
                end
            end

            if (out_fire && !redirect_valid) begin
                out_valid <= 1'b0;
                fetch_pc  <= pred_next_pc;
            end

            if (inst_resp_valid && req_pending) begin
                req_pending <= 1'b0;

                if (req_kill || redirect_valid) begin
                    req_kill <= 1'b0;
                end
                else begin
                    out_valid <= 1'b1;
                    out_pc    <= req_pc_hold;
                    out_inst  <= inst_resp_data;
                    out_err   <= inst_resp_err;
                    req_kill  <= 1'b0;
                end
            end

            if (req_fire) begin
                req_pending <= 1'b1;
                req_pc_hold <= inst_req_vaddr;
                req_kill    <= 1'b0;
            end
        end
    end

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
    output            take_branch,
    output            branch_valid,
    output            branch_cond,
    output            branch_jirl,

    output            ex_exc_valid,
    output      [5:0] ex_exc_ecode,
    output reg  [8:0] ex_exc_esubcode
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

    wire mdu_error_raw;

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
    reg        multi_error_hold;

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
        .mdu_res(mdu_res),
        .error(mdu_error_raw)
    );

    always @(posedge clk or negedge rst) begin
        if (!rst || flush) begin
            multi_busy        <= 1'b0;
            multi_done_hold   <= 1'b0;
            multi_is_mdu      <= 1'b0;
            multi_is_fpu      <= 1'b0;
            multi_result_hold <= 32'b0;
            multi_error_hold  <= 1'b0;
        end
        else begin
            if (start_multi) begin
                multi_busy      <= 1'b1;
                multi_done_hold <= 1'b0;
                multi_is_mdu    <= is_mdu_inst;
                multi_is_fpu    <= is_fpu_inst;
                multi_error_hold<= 1'b0;
            end

            if (multi_busy && multi_is_mdu && mdu_ready) begin
                multi_busy        <= 1'b0;
                multi_done_hold   <= 1'b1;
                multi_result_hold <= mdu_res;
                multi_error_hold  <= mdu_error_raw;
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
        .rdata1(rdata1),
        .rdata2(rdata2),
        .branch(branch),

        .branch_target(branch_target),
        .take_branch(take_branch),

        .branch_valid(branch_valid),
        .branch_cond(branch_cond),
        .branch_jirl(branch_jirl)
    );

    wire ex_exc_md_valid = ex_valid && (UnitSel == `MDU_use) && multi_done_hold && multi_error_hold;

    assign ex_exc_valid = ex_exc_md_valid;

    assign ex_exc_ecode = ex_exc_valid ? `ECODE_FPE : 6'b0;

    always @(*) begin
        case(1'b1)
            ex_exc_md_valid: ex_exc_esubcode = 9'd1;
            default: ex_exc_esubcode = 9'd0;
        endcase
    end

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

module LSU(
    input         clk,
    input         rst,
    input         flush,

    input         mem_valid,
    input         mem_en,
    input         mem_wr,
    input         mem_rd,
    input  [1:0]  mem_size,      // 00 byte, 01 half, 10 word
    input         mem_zero_ext,
    input  [31:0] mem_addr,
    input  [31:0] mem_wdata,

    // MEM/WB是否已经接收LSU结果
    input         result_taken,

    // 给流水线的控制
    output        mem_ready,
    output        mem_stall,

    // LSU输出给WB阶段的数据
    output [31:0] load_data,
    output        addr_err,
    output        bus_err,

    output        data_req_valid,
    input         data_req_ready,
    output        data_req_we,
    output [31:0] data_req_vaddr,
    output [31:0] data_req_wdata,
    output [3:0]  data_req_wstrb,
    output [1:0]  data_req_size,

    input         data_resp_valid,
    input  [31:0] data_resp_rdata,
    input         data_resp_err
);
    
    localparam MEM_BYTE = 2'd0;
    localparam MEM_HALF = 2'd1;
    localparam MEM_WORD = 2'd2;

    wire byte_access = (mem_size == MEM_BYTE);
    wire half_access = (mem_size == MEM_HALF);
    wire word_access = (mem_size == MEM_WORD);

    wire unalign_half = half_access && mem_addr[0];
    wire unalign_word = word_access && (mem_addr[1:0] != 2'b00);

    assign addr_err = mem_valid && mem_en && (unalign_half || unalign_word);

    //写掩码
    reg [3:0] wstrb;
    always @(*) begin
        case (mem_size)
            MEM_BYTE: begin
                case (mem_addr[1:0])
                    2'b00:   wstrb = 4'b0001;
                    2'b01:   wstrb = 4'b0010;
                    2'b10:   wstrb = 4'b0100;
                    2'b11:   wstrb = 4'b1000;
                    default: wstrb = 4'b0000;
                endcase
            end

            MEM_HALF: begin
                case (mem_addr[1])
                    1'b0:    wstrb = 4'b0011;
                    1'b1:    wstrb = 4'b1100;
                    default: wstrb = 4'b0000;
                endcase
            end

            MEM_WORD: begin
                wstrb = 4'b1111;
            end

            default: begin
                wstrb = 4'b0000;
            end
        endcase
    end

    reg [31:0] store_wdata;
    always @(*) begin
        case (mem_size)
            MEM_BYTE: begin
                case (mem_addr[1:0])
                    2'b00:   store_wdata = {24'b0, mem_wdata[7:0]};
                    2'b01:   store_wdata = {16'b0, mem_wdata[7:0], 8'b0};
                    2'b10:   store_wdata = {8'b0,  mem_wdata[7:0], 16'b0};
                    2'b11:   store_wdata = {mem_wdata[7:0], 24'b0};
                    default: store_wdata = 32'b0;
                endcase
            end

            MEM_HALF: begin
                case (mem_addr[1])
                    1'b0:    store_wdata = {16'b0, mem_wdata[15:0]};
                    1'b1:    store_wdata = {mem_wdata[15:0], 16'b0};
                    default: store_wdata = 32'b0;
                endcase
            end

            MEM_WORD: begin
                store_wdata = mem_wdata;
            end

            default: begin
                store_wdata = mem_wdata;
            end
        endcase
    end

    reg        req_pending;

    reg [31:0] addr_hold;
    reg [1:0]  size_hold;
    reg        zero_ext_hold;
    reg        rd_hold;
    reg        wr_hold;

    reg        done_valid;
    reg [31:0] resp_data_hold;
    reg        resp_err_hold;

    wire need_req = mem_valid && mem_en && !addr_err;

    assign data_req_valid = need_req && !req_pending && !done_valid;
    assign data_req_we    = mem_wr;
    assign data_req_vaddr = mem_addr;
    assign data_req_wdata = store_wdata;
    assign data_req_wstrb = mem_wr ? wstrb : 4'b0000;
    assign data_req_size  = mem_size;

    wire req_fire = data_req_valid && data_req_ready;

    assign mem_ready = !mem_valid ||
                       !mem_en    ||
                       addr_err   ||
                       done_valid;

    assign mem_stall = mem_valid &&
                       mem_en    &&
                       !addr_err &&
                       !done_valid;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            req_pending    <= 1'b0;

            addr_hold      <= 32'b0;
            size_hold      <= 2'b0;
            zero_ext_hold  <= 1'b0;
            rd_hold        <= 1'b0;
            wr_hold        <= 1'b0;

            done_valid     <= 1'b0;
            resp_data_hold <= 32'b0;
            resp_err_hold  <= 1'b0;
        end
        else if (flush) begin
            req_pending    <= 1'b0;
            done_valid     <= 1'b0;
            resp_data_hold <= 32'b0;
            resp_err_hold  <= 1'b0;
        end
        else begin
            // MEM/WB 已经接收 LSU 结果，清掉 done_valid
            if (result_taken) begin
                done_valid <= 1'b0;
            end

            // 请求被总线接收
            if (req_fire) begin
                req_pending   <= 1'b1;

                addr_hold     <= mem_addr;
                size_hold     <= mem_size;
                zero_ext_hold <= mem_zero_ext;
                rd_hold       <= mem_rd;
                wr_hold       <= mem_wr;
            end

            // 响应回来
            if (data_resp_valid && req_pending) begin
                req_pending    <= 1'b0;
                done_valid     <= 1'b1;
                resp_data_hold <= data_resp_rdata;
                resp_err_hold  <= data_resp_err;
            end
        end
    end

    reg [7:0]  load_byte;
    reg [15:0] load_half;
    reg [31:0] load_result;

    always @(*) begin
        case (addr_hold[1:0])
            2'b00:   load_byte = resp_data_hold[7:0];
            2'b01:   load_byte = resp_data_hold[15:8];
            2'b10:   load_byte = resp_data_hold[23:16];
            2'b11:   load_byte = resp_data_hold[31:24];
            default: load_byte = 8'b0;
        endcase
    end

    always @(*) begin
        case (addr_hold[1])
            1'b0:    load_half = resp_data_hold[15:0];
            1'b1:    load_half = resp_data_hold[31:16];
            default: load_half = 16'b0;
        endcase
    end

    always @(*) begin
        case (size_hold)
            MEM_BYTE: begin
                if (zero_ext_hold)
                    load_result = {24'b0, load_byte};
                else
                    load_result = {{24{load_byte[7]}}, load_byte};
            end

            MEM_HALF: begin
                if (zero_ext_hold)
                    load_result = {16'b0, load_half};
                else
                    load_result = {{16{load_half[15]}}, load_half};
            end

            MEM_WORD: begin
                load_result = resp_data_hold;
            end

            default: begin
                load_result = resp_data_hold;
            end
        endcase
    end

    assign load_data = load_result;

    assign bus_err = done_valid && resp_err_hold;

endmodule



module CSRFile(
    input clk,
    input rst,

    input[13:0] csr_raddr,
    output reg[31:0] csr_rdata,

    input         csr_we,
    input  [13:0] csr_waddr,
    input  [1 :0] csr_op,
    input  [31:0] csr_wdata,
    input  [31:0] csr_wmask,

    input         exc_valid,
    input  [31:0] exc_pc,
    input  [5 :0] exc_ecode,
    input  [8 :0] exc_esubcode,
    input  [31:0] exc_badv,

    input         ertn_valid,

    //外部中断
    input  [7:0]  hw_int,

    output [31:0] csr_eentry,
    output [31:0] csr_era,
    output        has_int,

    output [63:0] stable_timer
);

    reg [31:0] csr_crmd; //当前模式（是否开中断）
    reg [31:0] csr_prmd; //中断前模式（）
    reg [31:0] csr_ecfg; //中断屏蔽字
    reg [31:0] csr_estat;//异常状态字
    reg [31:0] csr_era_reg;//异常返回地址
    reg [31:0] csr_badv; //发生异常的地址
    reg [31:0] csr_eentry_reg;//异常处理程序入口地址

    reg [31:0] csr_tid;//线程id
    reg [31:0] csr_tcfg;//计时器配置（0位是使能，1位是是否循环，剩下的是具体数值）
    reg [31:0] csr_tval;//定时器当前值，定时器开始是每拍递减，到0触发定时器中断
    reg [31:0] csr_ticlr;//定时器中断清除寄存器
    reg [31:0] csr_llbctl;//ll、sc控制寄存器

    reg [63:0] timer_cnt;


    assign stable_timer = timer_cnt;
    assign csr_eentry   = csr_eentry_reg;
    assign csr_era      = csr_era_reg;

    // 简化：CRMD[2] 作为 IE，全局中断使能
    // ECFG[12:0] 为局部中断使能
    // ESTAT[12:0] 为中断 pending
    assign has_int = csr_crmd[2] && (|(csr_estat[12:0] & csr_ecfg[12:0]));

    wire timer_en       = csr_tcfg[0];
    wire timer_periodic = csr_tcfg[1];
    wire [29:0] tcfg_init = csr_tcfg[31:2];

    always @(*) begin
        case (csr_raddr)
            `CSR_CRMD:   csr_rdata = csr_crmd;
            `CSR_PRMD:   csr_rdata = csr_prmd;
            `CSR_ECFG:   csr_rdata = csr_ecfg;
            `CSR_ESTAT:  csr_rdata = csr_estat;
            `CSR_ERA:    csr_rdata = csr_era_reg;
            `CSR_BADV:   csr_rdata = csr_badv;
            `CSR_EENTRY: csr_rdata = csr_eentry_reg;

            `CSR_TID:    csr_rdata = csr_tid;
            `CSR_TCFG:   csr_rdata = csr_tcfg;
            `CSR_TVAL:   csr_rdata = csr_tval;
            `CSR_TICLR:  csr_rdata = csr_ticlr;

            `CSR_LLBCTL: csr_rdata = csr_llbctl;

            default:     csr_rdata = 32'b0;
        endcase
    end

    function [31:0] csr_write_value;
        input [31:0] old_value;
        input [1:0]  op;
        input [31:0] wdata;
        input [31:0] wmask;
        begin
            case (op)
                `CSR_WR: begin
                    csr_write_value = wdata;
                end

                `CSR_XCHG: begin
                    csr_write_value = (old_value & ~wmask) | (wdata & wmask);
                end

                default: begin
                    csr_write_value = old_value;
                end
            endcase
        end
    endfunction

    wire[31:0] tval = csr_write_value(csr_tcfg, csr_op, csr_wdata, csr_wmask);

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            csr_crmd       <= 32'd8;
            csr_prmd       <= 32'b0;
            csr_ecfg       <= 32'b0;
            csr_estat      <= 32'b0;
            csr_era_reg    <= 32'b0;
            csr_badv       <= 32'b0;
            csr_eentry_reg <= 32'h1C00_0100;

            csr_tid        <= 32'b0;
            csr_tcfg       <= 32'b0;
            csr_tval       <= 32'hffff_ffff;
            csr_ticlr      <= 32'b0;
            csr_llbctl     <= 32'b0;

            timer_cnt      <= 64'b0;
        end
        else begin
            timer_cnt <= timer_cnt + 64'd1;

            // 外部中断 pending，先映射到 ESTAT[9:2]
            csr_estat[9:2] <= hw_int;

            // timer
            if (timer_en) begin
                if (csr_tval == 32'b0) begin
                    csr_estat[11] <= 1'b1;  // timer interrupt pending

                    if (timer_periodic)
                        csr_tval <= {tcfg_init, 2'b0};
                    else
                        csr_tcfg[0] <= 1'b0;
                end
                else begin
                    csr_tval <= csr_tval - 32'd1;
                end
            end

            // 异常进入，优先级最高
            if (exc_valid) begin
                // PRMD 保存旧 PLV / IE
                csr_prmd[1:0] <= csr_crmd[1:0];
                csr_prmd[2]   <= csr_crmd[2];

                // 进入内核态，关闭中断
                csr_crmd[1:0] <= 2'b00;
                csr_crmd[2]   <= 1'b0;

                csr_era_reg       <= exc_pc;
                csr_badv          <= exc_badv;
                csr_estat[21:16]  <= exc_ecode;
                csr_estat[30:22]  <= exc_esubcode;
            end
            else if (ertn_valid) begin
                csr_crmd[1:0] <= csr_prmd[1:0];
                csr_crmd[2]   <= csr_prmd[2];
            end
            else if (csr_we) begin
                case (csr_waddr)
                    `CSR_CRMD:   csr_crmd       <= csr_write_value(csr_crmd,       csr_op, csr_wdata, csr_wmask);
                    `CSR_PRMD:   csr_prmd       <= csr_write_value(csr_prmd,       csr_op, csr_wdata, csr_wmask);
                    `CSR_ECFG:   csr_ecfg       <= csr_write_value(csr_ecfg,       csr_op, csr_wdata, csr_wmask);
                    `CSR_ESTAT:  csr_estat      <= csr_write_value(csr_estat,csr_op,csr_wdata,csr_wmask);
                    `CSR_ERA:    csr_era_reg    <= csr_write_value(csr_era_reg,    csr_op, csr_wdata, csr_wmask);
                    `CSR_BADV:   csr_badv       <= csr_write_value(csr_badv,       csr_op, csr_wdata, csr_wmask);
                    `CSR_EENTRY: csr_eentry_reg <= csr_write_value(csr_eentry_reg, csr_op, csr_wdata, csr_wmask);
                    `CSR_TID:    csr_tid        <= csr_write_value(csr_tid,        csr_op, csr_wdata, csr_wmask);

                    `CSR_TCFG: begin
                        csr_tcfg <= csr_write_value(csr_tcfg, csr_op, csr_wdata, csr_wmask);
                        csr_tval <= {tval[31:2], 2'b0};
                    end

                    `CSR_TICLR: begin
                        if (csr_wdata[0])
                            csr_estat[11] <= 1'b0;
                    end

                    `CSR_LLBCTL: begin
                        csr_llbctl <= csr_write_value(csr_llbctl, csr_op, csr_wdata, csr_wmask);
                    end

                    default: begin
                    end
                endcase
            end
        end
    end


endmodule

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


    wire redirect_valid;
    wire [31:0] redirect_pc;

    wire if_allowin = !mem_stall && !ex_stall && !load_use_stall && !csr_stall;
    
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
        else if (mem_stall || ex_stall || load_use_stall || csr_stall) begin
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
        end
        else if (mem_stall || ex_stall) begin
            idex_valid <= idex_valid;
        end
        else if (load_use_stall || csr_stall) begin
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

    // 目前没有 FPR 顶层的话，先临时接 0。
    // 后面你要真的跑浮点，需要加 FPR 文件。
    wire [31:0] ex_fp_rdata1 = 32'b0;
    wire [31:0] ex_fp_rdata2 = 32'b0;

    wire        ex_stage_exc_valid;
    wire [5:0]  ex_stage_exc_ecode;

    wire exmem_ready = !mem_stall;

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

        .fp_rdata1(ex_fp_rdata1),
        .fp_rdata2(ex_fp_rdata2),

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
        end
        else if (ex_flush) begin
            exmem_valid <= 1'b0;
            exmem_regWr <= 1'b0;
            exmem_MemWr <= 1'b0;
            exmem_MemRd <= 1'b0;
            exmem_MemEn <= 1'b0;
        end
        else if(ex_stall) begin
            exmem_valid         <= 1'b0;
            exmem_regWr         <= 1'b0;
            exmem_MemWr         <= 1'b0;
            exmem_MemRd         <= 1'b0;
            exmem_MemEn         <= 1'b0;
        end
        else begin
            exmem_valid      <= idex_valid && ex_res_valid;
            exmem_ex_res     <= ex_res;
            exmem_store_data <= ex_data2;
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

            exmem_fp_to_gp_data <= ex_fp_to_gp_data;

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
        end
        else if (mem_stall) begin
            memwb_valid <= 1'd0;
            memwb_regWr <= 1'd0;
            memwb_waddr <= 5'd0;
            memwb_wdata <= 32'd0;
        end
        else begin
            memwb_valid <= mem_can_commit;
            memwb_regWr <= mem_can_commit && exmem_regWr;
            memwb_waddr <= exmem_regwaddr;
            memwb_wdata <= mem_stage_wdata;
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

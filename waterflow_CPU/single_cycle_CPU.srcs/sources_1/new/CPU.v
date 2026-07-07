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
    output reg[2:0]  branch,
    output           RegDst,
    output           RegDst1,
    output reg[3:0]  ALUctr,
    output           ALUSrc,
    output           MemWr,
    output           MemtoReg,
    output           PCtoReg,
    output           Src1Used,
    output           Src2Used,
    
    
    output           FpRegWr,
    output           isFpALU,
    output reg[3:0]  FPUctr,
    output           FpMemtoReg,
    output           FpMemWr,
    output           FptoGpr,
    output           GprtoFp,
    output           FpSrc1Used,
    output           FpSrc2Used
    
    );
    
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
    wire mulh_w = (inst[31:15] == 17'h00039);
    wire mulh_wu= (inst[31:15] == 17'h0003A);
    wire div_w  = (inst[31:15] == 17'h00040);
    wire mod_w  = (inst[31:15] == 17'h00041);
    wire div_wu = (inst[31:15] == 17'h00042);
    wire mod_wu = (inst[31:15] == 17'h00043);
    
    wire slli_w = (inst[31:15] == 17'h00081);
    wire srli_w = (inst[31:15] == 17'h00089);
    wire srai_w = (inst[31:15] == 17'h00091);
    
    wire ext_w_h= (inst[31:15] == 17'h00002);//rj[7:0]符号扩展成32位
    wire ext_w_b= (inst[31:15] == 17'h00003);//rj[15:0]符号扩展成32位
    wire clz_w  = (inst[31:15] == 17'h00004);//rj从高位开始连续0的个数
    wire ctz_w  = (inst[31:15] == 17'h00005);//rj从低位开始连续0的个数
    wire clo_w  = (inst[31:15] == 17'h00006);//rj从高位开始连续1的个数
    wire cto_w  = (inst[31:15] == 17'h00007);//rj从低位开始连续1的个数

    wire cpucfg = (inst[31:15] == 17'h0000b);//读CPU配置寄存器

    wire maskeqz= (inst[31:15] == 17'h00070);//如果rk==0写rj，否则写0
    wire masknez= (inst[31:15] == 17'h00071);//如果rk!=0写rj，否则写0

    wire break_ = (inst[31:15] == 17'h00054);//断点异常
    wire syscall= (inst[31:15] == 17'h00056);//系统调用，触发系统异常

    wire ertn   = (inst        == 32'h0648_3800);//返回异常处理程序

    wire dbar   = (inst[31:15] == 17'h070e4);//数据访问屏障
    wire ibar   = (inst[31:15] == 17'h070e5);//指令访问屏障
    wire idle   = (inst[31:15] == 17'h00c91);//等待中断
    wire cacop  = (inst[31:22] == 10'h018);//cache操作指令

    wire ll_w   = (inst[31:24] == 8'h20);//读内存+记录地址+设置llbit
    wire sc_w   = (inst[31:24] == 8'h21);//判断llbit，如果是1就写内存并且rd置1，否则rd置0不写内存

    wire csrrd  = (inst[31:24] == 8'h04) && (inst[9:5] == 5'h0);//从CSR寄存器中读数据到通用寄存器
    wire csrwr  = (inst[31:24] == 8'h04) && (inst[9:5] == 5'h1);//将rd数据写入CSR寄存器

    wire csrxchg= (inst[31:24] == 8'h04) && (inst[9:5] == 5'h2);//按rj掩码把rd数据写入CSR寄存器，并将CSR寄存器原来的值写入rd
    
    wire rdtimel_w=(inst[31:15]==17'h00000)&&(inst[14:10]==5'h18);//读64位计时器低32位
    wire rdtimeh_w=(inst[31:15]==17'h00000)&&(inst[14:10]==5'h19);//读64位计时器高32位
    
    

    wire alsl_w = (inst[31:17] == 15'h0002);//把rj左移sa2位后加rk
    
    
    wire fadd_s = (inst[31:15] == 17'h00201);
    wire fsub_s = (inst[31:15] == 17'h00205);
    wire fmul_s = (inst[31:15] == 17'h00209);
    
    wire fmov_s     = (inst[31:10] == 22'h004525);
    wire movgr2fr_w = (inst[31:10] == 22'h004529);
    wire movfr2gr_s = (inst[31:10] == 22'h00452d);
    
    wire fld_s  = (inst[31:22] == 10'h0ac);
    wire fst_s  = (inst[31:22] == 10'h0ad);
    
    wire bstrins_w = (inst[31:22] == 10'h006); //未实现
    wire bstrpick_w= (inst[31:22] == 10'h007); //未实现
    wire slti   = (inst[31:22] == 10'h008);//
    wire sltui  = (inst[31:22] == 10'h009);//
    wire
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
    wire pcalau12i=(inst[31:25] == 7'h0d);//计算PC值加上20位立即数，取高4位
    wire pcaddu12i=(inst[31:25] == 7'h0e);//计算PC值加上（20位立即数左移12位）
    
    wire beqz   = (inst[31:26] == 6'h10);
    wire jirl   = (inst[31:26] == 6'h13);
    wire b      = (inst[31:26] == 6'h14);
    wire bl     = (inst[31:26] == 6'h15);
    wire beq    = (inst[31:26] == 6'h16);
    wire bne    = (inst[31:26] == 6'h17);
    wire blt    = (inst[31:26] == 6'h18);
    wire bge    = (inst[31:26] == 6'h19);//有符号大于等于跳转
    wire bltu   = (inst[31:26] == 6'h1a);//无符号小于跳转
    wire bgeu   = (inst[31:26] == 6'h1b);

    
    
    wire r_type = add_w | sub_w | mul_w | and_ | nor_ | xor_ | or_ | slt | sltu | sll_w | srl_w | sra_w;
    
    assign regWr    = add_w|sub_w|mul_w|addi_w|ld_w|and_|nor_|or_|xor_|slt|sltu|sll_w|srl_w|sra_w|lu12i_w|bl|jirl|ori|slli_w|srli_w|srai_w;
    assign RegDst   = st_w|bne|blt|bgeu|beq;
    assign RegDst1  = bl;
    assign ALUSrc   = addi_w|ld_w|st_w|lu12i_w|ori|slli_w|srli_w|srai_w;
    assign MemWr    = st_w;
    assign MemtoReg = ld_w;
    assign PCtoReg  = bl | jirl;
    assign Src1Used = r_type | addi_w | ori | ld_w | st_w | beqz | jirl | bne | beq | blt | bgeu | slli_w | srli_w | srai_w;
    assign Src2Used = r_type | st_w   | bne | beq  | blt  | bgeu ;
    
    assign FpRegWr    = fadd_s | fsub_s | fmul_s | fmov_s | movgr2fr_w | fld_s ;
    assign isFpALU    = fadd_s | fsub_s | fmul_s | fmov_s ;
    assign FpMemtoReg = fld_s ;
    assign FpMemWr    = fst_s ;
    assign FptoGpr    = movfr2gr_s ;
    assign GprtoFp    = movgr2fr_w ;
    assign FpSrc1Used = fadd_s | fsub_s | fmul_s | fmov_s | movfr2gr_s ;
    assign FpSrc2Used = fadd_s | fsub_s | fmul_s | fst_s ;
    
    always @(*) begin
        case(1'b1)
            nop  :   ALUctr = 5'b00000;
            add_w:   ALUctr = 5'b00001;
            sub_w:   ALUctr = 5'b00010;
            bne  :   ALUctr = 5'b00010;
            beq  :   ALUctr = 5'b00010;
            blt  :   ALUctr = 5'b00010;
            bgeu :   ALUctr = 5'b00010;
            and_ :   ALUctr = 5'b00011;
            or_  :   ALUctr = 5'b00100;
            ori  :   ALUctr = 5'b00100;
            xor_ :   ALUctr = 5'b00101;
            slt  :   ALUctr = 5'b00110;
            sltu :   ALUctr = 5'b00111;
            sll_w:   ALUctr = 5'b01000;
            slli_w:  ALUctr = 5'b01000;
            srl_w:   ALUctr = 5'b01001;
            srli_w:  ALUctr = 5'b01001;
            sra_w:   ALUctr = 5'b01011;
            srai_w:  ALUctr = 5'b01011;
            nor_ :   ALUctr = 5'b01100;
            lu12i_w: ALUctr = 5'b01101;
            ext_w_h: ALUctr = 5'b01110;
            ext_w_b: ALUctr = 5'b01111;
            clz_w:   ALUctr = 5'b10000;
            ctz_w:   ALUctr = 5'b10001;
            clo_w:   ALUctr = 5'b10010;
            cto_w:   ALUctr = 5'b10011;
            default: ALUctr = 5'b00000;
        endcase
    end
    
    always @(*) begin
        case(1'b1)
            fadd_s:  FPUctr = 4'b0000;
            fsub_s:  FPUctr = 4'b0001;
            fmul_s:  FPUctr = 4'b0010;
            default: FPUctr = 4'b0000;
        endcase
    end
    
    always @(*) begin
        case(1'b1)
            bne:     branch = 3'b001;
            blt:     branch = 3'b010;
            b  :     branch = 3'b011;
            bl :     branch = 3'b011;
            jirl:    branch = 3'b100;
            beqz:    branch = 3'b101;
            bgeu:    branch = 3'b110;
            beq :    branch = 3'b111;
            default: branch = 3'b000;
        endcase
    end
endmodule

module ImmGen(
    input     [31:0] inst,
    output reg[31:0] imm32
);
    wire add_w  = (inst[31:15] == 17'h00020);
    wire sub_w  = (inst[31:15] == 17'h00022);
    wire nor_   = (inst[31:15] == 17'h00028);
    wire and_   = (inst[31:15] == 17'h00029);
    wire or_    = (inst[31:15] == 17'h0002A);
    wire xor_   = (inst[31:15] == 17'h0002B);
    wire slt    = (inst[31:15] == 17'h00024);
    wire sltu   = (inst[31:15] == 17'h00025);
    wire sll_w  = (inst[31:15] == 17'h0002E);
    wire srl_w  = (inst[31:15] == 17'h0002F);
    wire sra_w  = (inst[31:15] == 17'h00030);
    wire mul_w  = (inst[31:15] == 17'h00038);
    
    wire slli_w = (inst[31:15] == 17'h00081);
    wire srli_w = (inst[31:15] == 17'h00089);
    wire srai_w = (inst[31:15] == 17'h00091);
    
    wire addi_w = (inst[31:22] == 10'h00a);
    wire ori    = (inst[31:22] == 10'h00e);
    wire ld_w   = (inst[31:22] == 10'h0a2);
    wire st_w   = (inst[31:22] == 10'h0a6);
    
    wire lu12i_w= (inst[31:25] == 7'h0a);
    
    wire beqz   = (inst[31:26] == 6'h10);
    wire jirl   = (inst[31:26] == 6'h13);
    wire b      = (inst[31:26] == 6'h14);
    wire bl     = (inst[31:26] == 6'h15);
    wire beq    = (inst[31:26] == 6'h16);
    wire bne    = (inst[31:26] == 6'h17);
    wire blt    = (inst[31:26] == 6'h18);
    wire bgeu   = (inst[31:26] == 6'h1b);
    
    wire[4:0]  imm5   = inst[14:10];
    wire[11:0] imm12  = inst[21:10];
    wire[15:0] imm16  = inst[25:10];
    wire[19:0] imm20  = inst[24:5];
    wire[20:0] offs21 = {inst[4:0],inst[25:10]};
    wire[25:0] offs26 = {inst[9:0],inst[25:10]};
    
    always @(*) begin
        case(1'b1)
            addi_w: imm32 = {{20{imm12[11]}},imm12};
            ori:    imm32 = {20'd0,imm12};
            slli_w: imm32 = {27'd0,imm5};
            srli_w: imm32 = {27'd0,imm5};
            srai_w: imm32 = {27'd0,imm5};
            ld_w:   imm32 = {{20{imm12[11]}},imm12};
            st_w:   imm32 = {{20{imm12[11]}},imm12};
            beqz:   imm32 = {{9{offs21[20]}},offs21,2'b00};
            jirl:   imm32 = {{14{imm16[15]}},imm16,2'b00};
            b:      imm32 = {{4{offs26[25]}},offs26,2'b00};
            bl:     imm32 = {{4{offs26[25]}},offs26,2'b00};
            bne:    imm32 = {{14{imm16[15]}},imm16,2'b00};
            beq:    imm32 = {{14{imm16[15]}},imm16,2'b00};
            blt:    imm32 = {{14{imm16[15]}},imm16,2'b00};
            bgeu:   imm32 = {{14{imm16[15]}},imm16,2'b00};
            lu12i_w:imm32 = {imm20,12'b0};
            
            default:imm32 = 32'd0;
        endcase
    end 
endmodule

module EXU(
    input[31:0]  pc,
    input[31:0]  rdata1,
    input[31:0]  rdata2,
    input[31:0]  imm32,
    input[2:0]   branch,
    
    input        ALUSrc,
    input[3:0]   ALUctr,
    
    output[31:0] alu_res,
    output[31:0] branch_target,
    output       take_branch
);
    wire[31:0] op_b = ALUSrc ? imm32 : rdata2;
    wire ZF,SF,CF,OF;
    
    ALU u_alu(
        .A(rdata1),
        .B(op_b),
        .alu_op(ALUctr),
        .alu_res(alu_res),
        .ZF(ZF),
        .SF(SF),
        .CF(CF),
        .OF(OF)
    );
    
    BRU u_bru(
        .pc(pc),
        .imm32(imm32),
        .branch(branch),
        .rdata1(rdata1),
        .ZF(ZF),
        .SF(SF),
        .OF(OF),
        .CF(CF),
        .branch_target(branch_target),
        .take_branch(take_branch)
    );
    
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
    wire[3:0]  ALUctr;
    wire       ALUSrc;
    wire       MemWr;
    wire       MemtoReg;
    wire       PCtoReg;
    
    wire[4:0]  reg_raddr1;
    wire[31:0] reg_rdata1;
    wire[4:0]  reg_raddr2;
    wire[31:0] reg_rdata2;
    wire[4:0]  reg_waddr;
    wire[31:0] reg_wdata;
    
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
    reg [3:0]  idex_ALUctr;
    reg        idex_ALUSrc;
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
    wire id_ALUSrc;
    wire id_MemWr;
    wire id_MemtoReg;
    wire id_PCtoReg;
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
    
    assign reg_wdata   = PCtoReg ? nxt_pc : (MemtoReg ? mem_rdata : alu_res);
    
    assign reg_raddr1  = inst[9:5];
    assign reg_raddr2  = RegDst ? inst[4:0] : inst[14:10];
    assign reg_waddr   = RegDst1 ? 5'd1 : inst[4:0];
    
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
        .ALUSrc(id_ALUSrc),
        .MemWr(id_MemWr),
        .MemtoReg(id_MemtoReg),
        .PCtoReg(id_PCtoReg),
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
            idex_PCtoReg <= 1'b0;
            idex_branch <= 3'b000;
            idex_ALUctr <= 4'b0000;
            idex_ALUSrc <= 1'b0;
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
            idex_PCtoReg <= idex_PCtoReg;
            idex_branch <= idex_branch;
            idex_ALUctr <= idex_ALUctr;
            idex_ALUSrc <= idex_ALUSrc;
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
            idex_ALUSrc <= id_ALUSrc;
            idex_MemWr <= id_MemWr;
            idex_MemtoReg <= id_MemtoReg;
            idex_PCtoReg <= id_PCtoReg;
        end
    end
    
    
    
    EXU u_exu(
        .pc(idex_pc),
        .rdata1(idex_rdata1),
        .rdata2(idex_rdata2),
        .imm32(idex_imm32),
        .branch(idex_branch),
        .ALUSrc(idex_ALUSrc),
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
         exmem_PCtoReg <= 1'b0;
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
         exmem_PCtoReg <= idex_PCtoReg;
     end
end
    
    wire [31:0] mem_stage_wdata = exmem_PCtoReg ? exmem_pc4 : exmem_MemtoReg ? bus_rdata : exmem_alu_res;
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

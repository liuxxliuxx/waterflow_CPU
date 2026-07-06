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
    wire sll_w  = (inst[31:15] == 17'h0002E);
    wire srl_w  = (inst[31:15] == 17'h0002F);
    wire sra_w  = (inst[31:15] == 17'h00030);
    wire mul_w  = (inst[31:15] == 17'h00038);
    
    
    wire fadd_s = (inst[31:15] == 17'h00201);
    wire fsub_s = (inst[31:15] == 17'h00205);
    wire fmul_s = (inst[31:15] == 17'h00209);
    
    wire fmov_s     = (inst[31:10] == 22'h004525);
    wire movgr2fr_w = (inst[31:10] == 22'h004529);
    wire movfr2gr_s = (inst[31:10] == 22'h00452d);
    
    wire fld_s  = (inst[31:22] == 10'h0ac);
    wire fst_s  = (inst[31:22] == 10'h0ad);
    
    
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
    
    wire r_type = add_w | sub_w | mul_w | and_ | nor_ | xor_ | slt | sltu | sll_w | srl_w | sra_w;
    
    assign regWr    = add_w|sub_w|mul_w|addi_w|ld_w|and_|nor_|or_|xor_|slt|sltu|sll_w|srl_w|sra_w|lu12i_w|bl|jirl|ori;
    assign RegDst   = st_w|bne|blt|bgeu|beq;
    assign RegDst1  = bl;
    assign ALUSrc   = addi_w|ld_w|st_w|lu12i_w|ori;
    assign MemWr    = st_w;
    assign MemtoReg = ld_w;
    assign PCtoReg  = bl|jirl;
    assign Src1Used = r_type | addi_w | ori | ld_w | st_w | beqz | jirl | bne | beq | blt | bgeu ;
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
            add_w:   ALUctr = 4'b0000;
            sub_w:   ALUctr = 4'b0001;
            mul_w:   ALUctr = 4'b0010;
            bne  :   ALUctr = 4'b0001;
            beq  :   ALUctr = 4'b0001;
            blt  :   ALUctr = 4'b0001;
            bgeu :   ALUctr = 4'b0001;
            and_ :   ALUctr = 4'b0011;
            or_  :   ALUctr = 4'b0100;
            ori  :   ALUctr = 4'b0100;
            xor_ :   ALUctr = 4'b0101;
            slt  :   ALUctr = 4'b0110;
            sltu :   ALUctr = 4'b0111;
            sll_w:   ALUctr = 4'b1000;
            srl_w:   ALUctr = 4'b1001;
            sra_w:   ALUctr = 4'b1011;
            nor_ :   ALUctr = 4'b1100;
            lu12i_w: ALUctr = 4'b1101;
            default: ALUctr = 4'b0000;
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
    
    wire[11:0] imm12  = inst[21:10];
    wire[15:0] imm16  = inst[25:10];
    wire[19:0] imm20  = inst[24:5];
    wire[20:0] offs21 = {inst[4:0],inst[25:10]};
    wire[25:0] offs26 = {inst[9:0],inst[25:10]};
    
    always @(*) begin
        case(1'b1)
            addi_w: imm32 = {{20{imm12[11]}},imm12};
            ori:    imm32 = {20'd0,imm12};
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

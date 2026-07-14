`include "CPU_def.vh"
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

    reg [31:0] csr_dmw0;
    reg [31:0] csr_dmw1;

    reg [63:0] timer_cnt;



    assign stable_timer = timer_cnt;
    assign csr_eentry   = csr_eentry_reg;
    assign csr_era      = csr_era_reg;

    // CRMD[2] 作为全局中断使能
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

            `CSR_DMW0:   csr_rdata = csr_dmw0;
            `CSR_DMW1:   csr_rdata = csr_dmw1;

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
    wire[31:0] crmd = csr_write_value(csr_crmd, csr_op, csr_wdata, csr_wmask);
    wire[31:0] prmd = csr_write_value(csr_prmd, csr_op, csr_wdata, csr_wmask);
    wire[31:0] ecfg = csr_write_value(csr_ecfg, csr_op, csr_wdata, csr_wmask);
    wire[31:0] estat = csr_write_value(csr_estat, csr_op, csr_wdata, csr_wmask);
    wire[31:0] era_reg =csr_write_value(csr_era_reg, csr_op, csr_wdata, csr_wmask);
    wire[31:0] badv=csr_write_value(csr_badv, csr_op, csr_wdata, csr_wmask);
    wire[31:0] eentry=csr_write_value(csr_eentry_reg, csr_op, csr_wdata, csr_wmask);
    wire[31:0] tid=csr_write_value(csr_tid, csr_op, csr_wdata, csr_wmask);
    wire[31:0] tcfg=csr_write_value(csr_tcfg, csr_op, csr_wdata, csr_wmask);
    wire[31:0] llbctl=csr_write_value(csr_llbctl, csr_op, csr_wdata, csr_wmask);
    wire[31:0] dmw0=csr_write_value(csr_dmw0, csr_op, csr_wdata, csr_wmask);
    wire[31:0] dmw1=csr_write_value(csr_dmw1, csr_op, csr_wdata, csr_wmask);

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
            csr_dmw0           <= 32'b0;
            csr_dmw1           <= 32'b0;

            timer_cnt      <= 64'b0;
        end
        else begin
            timer_cnt <= timer_cnt + 64'd1;

            // 外部中断 pending，先映射到 ESTAT[9:2]
            csr_estat[9:2] <= hw_int;

            // timer
            if (timer_en) begin
                if (csr_tval == 32'b0) begin
                    csr_estat[11] <= 1'b1;  // 定时器中断pending

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
                if ((exc_ecode == `ECODE_ADEF) ||
                    (exc_ecode == `ECODE_ALE)  ||
                    (exc_ecode == `ECODE_ADEM)) begin
                    csr_badv <= exc_badv;
                end
                csr_estat[21:16]  <= exc_ecode;
                csr_estat[30:22]  <= exc_esubcode;
            end
            else if (ertn_valid) begin
                csr_crmd[1:0] <= csr_prmd[1:0];
                csr_crmd[2]   <= csr_prmd[2];
            end
            else if (csr_we) begin
                case (csr_waddr)
                    `CSR_CRMD:   csr_crmd       <= {22'b0,crmd[9:0]};
                    `CSR_PRMD:   csr_prmd       <= {28'b0,prmd[3:0]};
                    `CSR_ECFG:   csr_ecfg       <= {19'b0,ecfg[12:11],1'b0,ecfg[9:0]};
                    `CSR_ESTAT:  csr_estat[1:0] <= estat[1:0];
                    `CSR_ERA:    csr_era_reg    <= era_reg;
                    `CSR_BADV:   csr_badv       <= badv;
                    `CSR_EENTRY: csr_eentry_reg <= {eentry[31:6],6'b0};
                    `CSR_TID:    csr_tid        <= tid;
                    `CSR_DMW0: csr_dmw0 <= {dmw0[31:29],1'b0,dmw0[27:25],19'b0,dmw0[5:3],2'b0,dmw0[0]};
                    `CSR_DMW1: csr_dmw1 <= {dmw1[31:29],1'b0,dmw1[27:25],19'b0,dmw1[5:3],2'b0,dmw1[0]};

                    `CSR_TCFG: begin
                        csr_tcfg <= tcfg;
                        csr_tval <= {tval[31:2], 2'b0};
                    end

                    `CSR_TICLR: begin
                        if (csr_wdata[0])
                            csr_estat[11] <= 1'b0;
                    end

                    `CSR_LLBCTL: begin
                        csr_llbctl <= {29'b0,llbctl[2:0]};
                    end

                    default: begin
                    end
                endcase
            end
        end
    end


endmodule
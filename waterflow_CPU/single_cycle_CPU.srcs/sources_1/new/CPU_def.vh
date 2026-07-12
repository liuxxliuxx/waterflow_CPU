`define ALU_NOP       5'd0
`define ALU_ADD       5'd1
`define ALU_SUB       5'd2
`define ALU_AND       5'd3
`define ALU_OR        5'd4
`define ALU_XOR       5'd5
`define ALU_SLT       5'd6
`define ALU_SLTU      5'd7
`define ALU_SLL       5'd8
`define ALU_SRL       5'd9
`define ALU_SRA       5'd11
`define ALU_NOR       5'd12
`define ALU_LU12I     5'd13
`define ALU_EXT_H     5'd14
`define ALU_EXT_B     5'd15
`define ALU_CLZ       5'd16
`define ALU_CTZ       5'd17
`define ALU_CLO       5'd18
`define ALU_CTO       5'd19
`define ALU_ANDN      5'd20
`define ALU_ORN       5'd21
`define ALU_ALSL      5'd22
`define ALU_MASKEQZ   5'd23
`define ALU_MASKNEZ   5'd24
`define ALU_PCALAU    5'd25
`define ALU_CPUCFG    5'd26

`define WB_ALU        4'd0
`define WB_MEM        4'd1
`define WB_PC4        4'd2
`define WB_CSR        4'd3
`define WB_CPUCFG     4'd4
`define WB_TIMER      4'd5
`define WB_FPR        4'd6 
`define WB_SC         4'd7
`define WB_MDU        4'd8

`define BR_NONE       4'd0
`define BR_BNE        4'd1
`define BR_BLT        4'd2
`define BR_B          4'd3
`define BR_JIRL       4'd4
`define BR_BEQZ       4'd5
`define BR_BGEU       4'd6
`define BR_BEQ        4'd7
`define BR_BGE        4'd8
`define BR_BLTU       4'd9
`define BR_BNEZ       4'd10

`define FP_none       4'd0
`define FP_adds       4'd1
`define FP_subs       4'd2
`define FP_muls       4'd3
`define FP_movs       4'd4

`define ALU_use       2'd0
`define MDU_use       2'd1
`define FPU_use       2'd2

`define MDU_NONE      3'd0
`define MDU_MULW      3'd1
`define MDU_MULHW     3'd2
`define MDU_MULHWU    3'd3
`define MDU_DIVW      3'd4
`define MDU_MODW      3'd5
`define MDU_DIVWU     3'd6
`define MDU_MODWU     3'd7

`define FPWB_FPU      2'd0
`define FPWB_MEM      2'd1
`define FPWB_GPR      2'd2

`define ECODE_INT     6'h00
`define ECODE_ADEF    6'h08   // 取指地址错 / 取指错误
`define ECODE_ALE     6'h09   // 地址非对齐
`define ECODE_SYS     6'h0b
`define ECODE_BRK     6'h0c
`define ECODE_INE     6'h0d
`define ECODE_IPE     6'h0e
`define ECODE_FPD     6'h0f
`define ECODE_ADEM    6'h10   // 数据访存总线/地址错误，简化用
`define ECODE_FPE     6'h12

`define SP_NONE       3'd0
`define SP_ERTN       3'd1
`define SP_DBAR       3'd2
`define SP_IBAR       3'd3
`define SP_IDLE       3'd4
`define SP_CACOP      3'd5

`define CSR_RD        2'd0
`define CSR_WR        2'd1
`define CSR_XCHG      2'd2


`define CSR_CRMD      14'h000
`define CSR_PRMD      14'h001
`define CSR_ECFG      14'h004
`define CSR_ESTAT     14'h005
`define CSR_ERA       14'h006
`define CSR_BADV      14'h007
`define CSR_EENTRY    14'h00c

`define CSR_TID       14'h040
`define CSR_TCFG      14'h041
`define CSR_TVAL      14'h042
`define CSR_TICLR     14'h044

`define CSR_LLBCTL    14'h060

`define CSR_DMW0      14'h180
`define CSR_DMW1      14'h181


`define IMM_NONE        4'd0
`define IMM_SI12        4'd1
`define IMM_UI12        4'd2
`define IMM_UI5         4'd3
`define IMM_SI20_LSL12  4'd4
`define IMM_SI20_LSL2   4'd5
`define IMM_SI14_LSL2   4'd6
`define IMM_SI16_LSL2   4'd7
`define IMM_SI21_LSL2   4'd8
`define IMM_SI26_LSL2   4'd9
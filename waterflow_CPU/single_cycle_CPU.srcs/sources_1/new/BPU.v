`include "CPU_def.vh"
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

    localparam INDEX_BITS = 6;
    localparam ENTRY_NUM  = 64;
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
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
    input         inst_resp_err,

    output        if_pred_taken,
    output [31:0] if_pred_target,
    output [31:0] bpu_query_pc,
    output [31:0] bpu_query_inst
);
    reg [31:0] fetch_pc;

    reg        redirect_pending;
    reg [31:0] redirect_pc_hold;
    reg        req_pending;
    reg [31:0] req_pc_hold;

    reg req_kill;

    reg        slot0_valid;
    reg [31:0] slot0_pc;
    reg [31:0] slot0_inst;
    reg        slot0_err;
    reg        slot0_pred_taken;
    reg [31:0] slot0_pred_target;

    reg        slot1_valid;
    reg [31:0] slot1_pc;
    reg [31:0] slot1_inst;
    reg        slot1_err;
    reg        slot1_pred_taken;
    reg [31:0] slot1_pred_target;

    wire pop = slot0_valid && if_allowin&& !redirect_valid;

    wire resp_fire = inst_resp_valid && req_pending;

    wire resp_drop =
        req_kill || redirect_valid;

    wire resp_good =
        resp_fire && !resp_drop;

    wire [31:0] resp_next_pc = pred_taken ? pred_target : req_pc_hold + 32'd4;

    wire [2:0] token_count ={2'b0, slot0_valid} + {2'b0, slot1_valid} + {2'b0, req_pending};

    wire request_slot_free = !req_pending || resp_fire;

    wire capacity_available =
        (token_count < 3'd2) ||
        pop ||
        (resp_fire && resp_drop);

    wire [31:0] issue_pc =
        redirect_pending ? redirect_pc_hold :
        resp_good        ? resp_next_pc      :
                        fetch_pc;

    wire can_issue = request_slot_free && capacity_available && !redirect_valid;

    assign inst_req_valid = can_issue;
    assign inst_req_vaddr = issue_pc;

    wire req_fire = inst_req_valid && inst_req_ready;

    assign if_valid = slot0_valid;
    assign if_pc    = slot0_pc;
    assign if_pc4   = slot0_pc + 32'd4;
    assign if_inst  = slot0_inst;
    assign if_err   = slot0_err;

    assign if_pred_taken  = slot0_pred_taken;
    assign if_pred_target = slot0_pred_target;

    assign bpu_query_pc   = req_pc_hold;
    assign bpu_query_inst = inst_resp_data;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            fetch_pc          <= 32'h1c00_0000;

            redirect_pending  <= 1'b0;
            redirect_pc_hold  <= 32'b0;

            req_pending       <= 1'b0;
            req_pc_hold       <= 32'b0;
            req_kill          <= 1'b0;

            slot0_valid       <= 1'b0;
            slot0_pc          <= 32'b0;
            slot0_inst        <= 32'b0;
            slot0_err         <= 1'b0;
            slot0_pred_taken  <= 1'b0;
            slot0_pred_target <= 32'b0;

            slot1_valid       <= 1'b0;
            slot1_pc          <= 32'b0;
            slot1_inst        <= 32'b0;
            slot1_err         <= 1'b0;
            slot1_pred_taken  <= 1'b0;
            slot1_pred_target <= 32'b0;
        end
        else begin
            if (redirect_valid) begin
                slot0_valid      <= 1'b0;
                slot1_valid      <= 1'b0;

                fetch_pc         <= redirect_pc;
                redirect_pending <= 1'b1;
                redirect_pc_hold <= redirect_pc;

                if (resp_fire) begin
                    //丢弃响应数据，清除pending
                    req_pending <= 1'b0;
                    req_kill    <= 1'b0;
                end
                else begin
                    //丢弃响应数据
                    req_kill <= req_pending;
                end
            end
            else begin
                if (resp_fire) begin
                    req_pending <= 1'b0;
                    req_kill    <= 1'b0;

                    if (resp_good)//如果需要保留，更新pc
                        fetch_pc <= resp_next_pc;
                end

                if (req_fire) begin
                    req_pending <= 1'b1;
                    req_pc_hold <= issue_pc;
                    req_kill    <= 1'b0;

                    if (redirect_pending)
                        redirect_pending <= 1'b0;
                end
                case ({resp_good, pop})
                    2'b00: begin
                    end
                    2'b01: begin//当前指令已经被IF/ID吸收，并且没有新指令返回
                        if (slot1_valid) begin
                            //槽位1的数据送到槽位0
                            slot0_valid       <= 1'b1;
                            slot0_pc          <= slot1_pc;
                            slot0_inst        <= slot1_inst;
                            slot0_err         <= slot1_err;
                            slot0_pred_taken  <= slot1_pred_taken;
                            slot0_pred_target <= slot1_pred_target;

                            slot1_valid <= 1'b0;
                        end
                        else begin
                            slot0_valid <= 1'b0;
                        end
                    end

                    2'b10: begin//当前有新指令返回，但没有指令被吸收
                        if (!slot0_valid) begin
                            //如果槽位0为空，送入槽位0
                            slot0_valid       <= 1'b1;
                            slot0_pc          <= req_pc_hold;
                            slot0_inst        <= inst_resp_data;
                            slot0_err         <= inst_resp_err;
                            slot0_pred_taken  <= pred_taken;
                            slot0_pred_target <= pred_target;
                        end
                        else begin
                            //送入槽位1
                            slot1_valid       <= 1'b1;
                            slot1_pc          <= req_pc_hold;
                            slot1_inst        <= inst_resp_data;
                            slot1_err         <= inst_resp_err;
                            slot1_pred_taken  <= pred_taken;
                            slot1_pred_target <= pred_target;
                        end
                    end

                    2'b11: begin//当前既有新指令返回，又有指令被吸收
                        if (slot1_valid) begin
                            //槽1的指令送入槽0
                            slot0_valid       <= 1'b1;
                            slot0_pc          <= slot1_pc;
                            slot0_inst        <= slot1_inst;
                            slot0_err         <= slot1_err;
                            slot0_pred_taken  <= slot1_pred_taken;
                            slot0_pred_target <= slot1_pred_target;
                            //新接收的指令送入槽1
                            slot1_valid       <= 1'b1;
                            slot1_pc          <= req_pc_hold;
                            slot1_inst        <= inst_resp_data;
                            slot1_err         <= inst_resp_err;
                            slot1_pred_taken  <= pred_taken;
                            slot1_pred_target <= pred_target;
                        end
                        else begin
                            //槽1没有数据，直接覆盖槽0
                            slot0_valid       <= 1'b1;
                            slot0_pc          <= req_pc_hold;
                            slot0_inst        <= inst_resp_data;
                            slot0_err         <= inst_resp_err;
                            slot0_pred_taken  <= pred_taken;
                            slot0_pred_target <= pred_target;

                            slot1_valid <= 1'b0;
                        end
                    end
                endcase
            end
        end
    end

endmodule
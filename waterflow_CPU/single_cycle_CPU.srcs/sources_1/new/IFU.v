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
    output [31:0] if_pred_target
);
    reg [31:0] fetch_pc;

    reg        redirect_pending;
    reg [31:0] redirect_pc_hold;
    reg        req_pending;
    reg [31:0] req_pc_hold;

    reg req_kill;
    reg out_valid;
    reg [31:0] out_pc;
    reg [31:0] out_inst;
    reg out_err;

    reg        out_pred_taken;
    reg [31:0] out_pred_target;

    wire[31:0] out_pc4 = out_pc + 32'd4;

    wire out_fire = out_valid && if_allowin;

    wire[31:0] pred_next_pc = pred_taken ? pred_target : (req_pc_hold + 32'd4);

    wire can_issue = !req_pending && (!out_valid || if_allowin);

    wire [31:0] issue_pc =redirect_pending ? redirect_pc_hold : fetch_pc;

    assign inst_req_valid = can_issue && !redirect_valid;
    assign inst_req_vaddr = issue_pc;

    wire req_fire = inst_req_valid && inst_req_ready;

    assign if_valid = out_valid;
    assign if_pc    = out_pc;
    assign if_pc4   = out_pc4;
    assign if_inst  = out_inst;
    assign if_err   = out_err;

    assign if_pred_taken  = out_pred_taken;
    assign if_pred_target = out_pred_target;

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
            redirect_pending <= 1'b0;
            redirect_pc_hold <= 32'b0;

            out_pred_taken  <= 1'b0;
            out_pred_target <= 32'b0;
        end
        else begin
            if (redirect_valid) begin
                redirect_pending <= 1'b1;
                redirect_pc_hold <= redirect_pc;
                fetch_pc  <= redirect_pc;
                out_valid <= 1'b0;
                out_pc    <= 32'b0;
                out_inst  <= 32'b0;
                out_err   <= 1'b0;

                out_pred_taken  <= 1'b0;
                out_pred_target <= 32'b0;

                req_kill <= req_pending;
            end

            if (out_fire && !redirect_valid) begin
                out_valid <= 1'b0;
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

                    out_pred_taken  <= pred_taken;
                    out_pred_target <= pred_target;
                    fetch_pc        <= pred_next_pc;


                    req_kill  <= 1'b0;
                end
            end

            if (req_fire) begin
                req_pending <= 1'b1;
                req_pc_hold <= inst_req_vaddr;
                req_kill    <= 1'b0;
                if (redirect_pending)
                    redirect_pending <= 1'b0;
            end
        end
    end

endmodule
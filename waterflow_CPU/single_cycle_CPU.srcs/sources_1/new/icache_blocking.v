`timescale 1ns / 1ps
module icache_blocking(
    input wire clk,
    input wire rst,
    input wire req_valid,
    output wire req_ready,
    input wire [31:0] req_addr,
    output reg resp_valid,
    input wire resp_ready,
    output reg [31:0] resp_inst,
    output reg mem_req_valid,
    input wire mem_req_ready,
    output reg [31:0] mem_req_addr,
    input wire mem_resp_valid,
    input wire [31:0] mem_resp_rdata
);
    (* ram_style = "block" *) reg [31:0] data [0:255];
    (* ram_style = "block" *) reg [21:0] tag [0:255];
    reg [255:0] valid;

    reg [1:0] state;
    reg [31:0] saved_addr;
    reg mem_req_sent;

    reg [31:0] lookup_data_r;
    reg [21:0] lookup_tag_r;

    wire [7:0] index = req_addr[9:2];
    wire [21:0] req_tag = req_addr[31:10];

    localparam S_IDLE = 2'd0,
               S_WAIT_MEM = 2'd1,
               S_RESP = 2'd2,
               S_LOOKUP = 2'd3;

    wire hit = valid[saved_addr[9:2]] &&
               (lookup_tag_r == saved_addr[31:10]);

    assign req_ready = (state == S_IDLE) && (!resp_valid || resp_ready);

    always @(posedge clk) begin
        if (req_valid && req_ready) begin
            lookup_data_r <= data[index];
            lookup_tag_r <= tag[index];
        end

        if ((state == S_WAIT_MEM) && mem_resp_valid) begin
            data[saved_addr[9:2]] <= mem_resp_rdata;
            tag[saved_addr[9:2]] <= saved_addr[31:10];
        end
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= S_IDLE;
            resp_valid <= 1'b0;
            mem_req_valid <= 1'b0;
            mem_req_sent <= 1'b0;
            resp_inst <= 32'h0340_0000;
            mem_req_addr <= 32'h0;
            saved_addr <= 32'h0;
            valid <= 256'b0;
        end else begin
            if (resp_valid && resp_ready)
                resp_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    mem_req_valid <= 1'b0;
                    mem_req_sent <= 1'b0;

                    if (req_valid && req_ready) begin
                        saved_addr <= req_addr;
                        state <= S_LOOKUP;
                    end
                end

                S_LOOKUP: begin
                    if (hit) begin
                        resp_inst <= lookup_data_r;
                        resp_valid <= 1'b1;
                        state <= S_RESP;
                    end else begin
                        mem_req_valid <= 1'b1;
                        mem_req_addr <= saved_addr;
                        mem_req_sent <= 1'b0;
                        state <= S_WAIT_MEM;
                    end
                end

                S_WAIT_MEM: begin
                    mem_req_addr <= saved_addr;

                    if (!mem_req_sent) begin
                        mem_req_valid <= 1'b1;
                        if (mem_req_ready) begin
                            mem_req_valid <= 1'b0;
                            mem_req_sent <= 1'b1;
                        end
                    end else begin
                        mem_req_valid <= 1'b0;
                    end

                    if (mem_resp_valid) begin
                        valid[saved_addr[9:2]] <= 1'b1;
                        resp_inst <= mem_resp_rdata;
                        resp_valid <= 1'b1;
                        mem_req_valid <= 1'b0;
                        state <= S_RESP;
                    end
                end

                S_RESP: begin
                    mem_req_valid <= 1'b0;
                    if (!resp_valid || resp_ready)
                        state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                    resp_valid <= 1'b0;
                    mem_req_valid <= 1'b0;
                    mem_req_sent <= 1'b0;
                end
            endcase
        end
    end
endmodule

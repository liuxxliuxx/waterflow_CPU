`timescale 1ns / 1ps

module dcache_blocking(
    input wire clk,
    input wire rst,
    input wire req_valid,
    output wire req_ready,
    input wire req_we,
    input wire [1:0] req_size,
    input wire [3:0] req_wstrb,
    input wire [31:0] req_addr,
    input wire [31:0] req_wdata,
    output reg resp_valid,
    input wire resp_ready,
    output reg [31:0] resp_rdata,
    output reg mem_req_valid,
    input wire mem_req_ready,
    output reg mem_req_we,
    output reg [3:0] mem_req_wstrb,
    output reg [31:0] mem_req_addr,
    output reg [31:0] mem_req_wdata,
    input wire mem_resp_valid,
    input wire [31:0] mem_resp_rdata
);
    (* ram_style = "block" *) reg [31:0] data [0:255];
    (* ram_style = "block" *) reg [21:0] tag [0:255];
    reg [255:0] valid;
    reg [255:0] dirty;

    reg [2:0] state;
    reg [31:0] saved_addr, saved_wdata;
    reg [3:0] saved_wstrb;
    reg saved_we;

    reg [31:0] lookup_data_r;
    reg [21:0] lookup_tag_r;
    reg lookup_valid_r;
    reg lookup_dirty_r;

    reg [31:0] victim_data_r;
    reg [21:0] victim_tag_r;

    wire [7:0] index = req_addr[9:2];
    wire [21:0] req_tag = req_addr[31:10];
    wire hit = lookup_valid_r &&
               (lookup_tag_r == saved_addr[31:10]);

    localparam S_IDLE = 3'd0,
               S_SEND_WB = 3'd1,
               S_SEND_MEM = 3'd2,
               S_WAIT_MEM = 3'd3,
               S_RESP = 3'd4,
               S_LOOKUP = 3'd5;

    assign req_ready = (state == S_IDLE) && (!resp_valid || resp_ready);

    function [31:0] merge_word;
        input [31:0] old_word;
        input [31:0] new_word;
        input [3:0] strobe;
        begin
            merge_word = old_word;
            if (strobe[0]) merge_word[7:0] = new_word[7:0];
            if (strobe[1]) merge_word[15:8] = new_word[15:8];
            if (strobe[2]) merge_word[23:16] = new_word[23:16];
            if (strobe[3]) merge_word[31:24] = new_word[31:24];
        end
    endfunction

    wire store_hit_write = (state == S_LOOKUP) && hit && saved_we;
    wire refill_write = (state == S_WAIT_MEM) && mem_resp_valid;
    wire cache_data_we = store_hit_write || refill_write;
    wire [7:0] cache_write_index = saved_addr[9:2];
    wire [31:0] cache_write_data =
        store_hit_write
        ? merge_word(lookup_data_r, saved_wdata, saved_wstrb)
        : (saved_we
           ? merge_word(mem_resp_rdata, saved_wdata, saved_wstrb)
           : mem_resp_rdata);

    always @(posedge clk) begin
        if (req_valid && req_ready) begin
            lookup_data_r <= data[index];
            lookup_tag_r <= tag[index];
            lookup_valid_r <= valid[index];
            lookup_dirty_r <= dirty[index];
        end

        if (cache_data_we)
            data[cache_write_index] <= cache_write_data;

        if (refill_write)
            tag[cache_write_index] <= saved_addr[31:10];
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= S_IDLE;
            resp_valid <= 1'b0;
            mem_req_valid <= 1'b0;
            resp_rdata <= 32'h0;
            mem_req_we <= 1'b0;
            mem_req_wstrb <= 4'h0;
            mem_req_addr <= 32'h0;
            mem_req_wdata <= 32'h0;
            saved_addr <= 32'h0;
            saved_wdata <= 32'h0;
            saved_wstrb <= 4'h0;
            saved_we <= 1'b0;
            victim_data_r <= 32'h0;
            victim_tag_r <= 22'h0;
            valid <= 256'b0;
            dirty <= 256'b0;
        end else begin
            if (resp_valid && resp_ready)
                resp_valid <= 1'b0;

            mem_req_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (req_valid && req_ready) begin
                        saved_addr <= req_addr;
                        saved_we <= req_we;
                        saved_wdata <= req_wdata;
                        saved_wstrb <= req_wstrb;
                        state <= S_LOOKUP;
                    end
                end

                S_LOOKUP: begin
                    if (hit) begin
                        if (saved_we) begin
                            dirty[saved_addr[9:2]] <= 1'b1;
                            resp_rdata <= 32'h0;
                        end else begin
                            resp_rdata <= lookup_data_r;
                        end

                        resp_valid <= 1'b1;
                        state <= S_RESP;
                    end else begin
                        victim_data_r <= lookup_data_r;
                        victim_tag_r <= lookup_tag_r;

                        if (lookup_valid_r && lookup_dirty_r)
                            state <= S_SEND_WB;
                        else
                            state <= S_SEND_MEM;
                    end
                end

                S_SEND_WB: begin
                    mem_req_valid <= 1'b1;
                    mem_req_we <= 1'b1;
                    mem_req_wstrb <= 4'hF;
                    mem_req_addr <= {
                        victim_tag_r,
                        saved_addr[9:2],
                        2'b00
                    };
                    mem_req_wdata <= victim_data_r;

                    if (mem_req_valid && mem_req_ready) begin
                        mem_req_valid <= 1'b0;
                        state <= S_SEND_MEM;
                    end
                end

                S_SEND_MEM: begin
                    mem_req_valid <= 1'b1;
                    mem_req_we <= 1'b0;
                    mem_req_wstrb <= 4'h0;
                    mem_req_addr <= saved_addr;
                    mem_req_wdata <= 32'h0;

                    if (mem_req_valid && mem_req_ready) begin
                        mem_req_valid <= 1'b0;
                        state <= S_WAIT_MEM;
                    end
                end

                S_WAIT_MEM: begin
                    if (mem_resp_valid) begin
                        valid[saved_addr[9:2]] <= 1'b1;

                        if (saved_we) begin
                            dirty[saved_addr[9:2]] <= 1'b1;
                            resp_rdata <= 32'h0;
                        end else begin
                            dirty[saved_addr[9:2]] <= 1'b0;
                            resp_rdata <= mem_resp_rdata;
                        end

                        resp_valid <= 1'b1;
                        state <= S_RESP;
                    end
                end

                S_RESP: begin
                    if (!resp_valid || resp_ready)
                        state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                    resp_valid <= 1'b0;
                    mem_req_valid <= 1'b0;
                end
            endcase
        end
    end

endmodule

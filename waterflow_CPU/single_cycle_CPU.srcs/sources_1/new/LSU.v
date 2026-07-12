`include "CPU_def.vh"
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
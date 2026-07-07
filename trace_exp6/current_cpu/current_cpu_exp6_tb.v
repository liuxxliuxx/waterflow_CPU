`timescale 1ns / 1ps

module Instr_rom(
    input  [15:0] addr,
    output [31:0] data
);
    reg [31:0] inst_mem [0:65535];
    initial begin
        $readmemb("inst_ram.mif", inst_mem);
    end
    assign data = inst_mem[addr];
endmodule

module tb_top;
    localparam [31:0] END_PC     = 32'h1c000100;
    localparam integer MAX_CYCLE = 5000000;

    reg clk;
    reg resetn;

    wire [4:0]  test_addr = 5'd0;
    wire [31:0] test_data;
    wire [31:0] test_pc_cur;
    wire [31:0] test_inst;
    wire        bus_req;
    wire        bus_we;
    wire [31:0] bus_addr;
    wire [31:0] bus_wdata;
    wire [31:0] bus_rdata;
    wire        bus_ready;

    CPU u_cpu(
        .clk(clk),
        .rst(resetn),
        .test_addr(test_addr),
        .test_data(test_data),
        .test_pc_cur(test_pc_cur),
        .test_inst(test_inst),
        .bus_req(bus_req),
        .bus_we(bus_we),
        .bus_addr(bus_addr),
        .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata),
        .bus_ready(bus_ready)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        resetn = 1'b0;
        #2000;
        resetn = 1'b1;
    end

    reg [31:0] data_mem [0:65535];
    initial begin
        $readmemb("inst_ram.mif", data_mem);
    end

    reg [31:0] num_data;
    reg        open_trace;
    reg        num_monitor;
    reg [31:0] simu_flag;
    reg [31:0] io_simu;
    reg [7:0]  uart_data;
    reg        uart_valid;
    reg [31:0] timer;

    localparam [7:0] switch = 8'hff;
    wire [31:0] switch_data   = {24'd0, switch};
    wire [31:0] sw_inter_data = {16'd0,
                                 switch[7], 1'b0, switch[6], 1'b0,
                                 switch[5], 1'b0, switch[4], 1'b0,
                                 switch[3], 1'b0, switch[2], 1'b0,
                                 switch[1], 1'b0, switch[0], 1'b0};

    wire conf_sel = (bus_addr[31:16] == 16'hbfaf);
    wire [15:0] conf_addr = bus_addr[15:0];
    wire [15:0] mem_addr  = bus_addr[17:2];

    wire [31:0] conf_rdata =
        (conf_addr == 16'hf050) ? num_data :
        (conf_addr == 16'hf060) ? switch_data :
        (conf_addr == 16'hf090) ? sw_inter_data :
        (conf_addr == 16'hff00) ? io_simu :
        (conf_addr == 16'hff20) ? simu_flag :
        (conf_addr == 16'hff30) ? {31'd0, open_trace} :
        (conf_addr == 16'hff40) ? {31'd0, num_monitor} :
        (conf_addr == 16'he000) ? timer :
        32'd0;

    assign bus_ready = bus_req;
    assign bus_rdata = conf_sel ? conf_rdata : data_mem[mem_addr];

    always @(posedge clk) begin
        if (!resetn) begin
            num_data    <= 32'd0;
            open_trace  <= 1'b1;
            num_monitor <= 1'b1;
            simu_flag   <= 32'hffffffff;
            io_simu     <= 32'd0;
            uart_data   <= 8'd0;
            uart_valid  <= 1'b0;
            timer       <= 32'd0;
        end
        else begin
            timer      <= timer + 1'b1;
            uart_valid <= 1'b0;

            if (bus_req && bus_we) begin
                if (conf_sel) begin
                    case (conf_addr)
                        16'hf050: num_data    <= bus_wdata;
                        16'hff00: io_simu     <= {bus_wdata[15:0], bus_wdata[31:16]};
                        16'hff10: begin
                            uart_data  <= bus_wdata[7:0];
                            uart_valid <= 1'b1;
                        end
                        16'hff30: open_trace  <= |bus_wdata;
                        16'hff40: num_monitor <= bus_wdata[0];
                    endcase
                end
                else begin
                    data_mem[mem_addr] <= bus_wdata;
                end
            end
        end
    end

    reg [31:0] exmem_pc_shadow;
    reg [31:0] memwb_pc_shadow;
    always @(posedge clk) begin
        if (!resetn) begin
            exmem_pc_shadow <= 32'd0;
            memwb_pc_shadow <= 32'd0;
        end
        else if (!u_cpu.mem_stall) begin
            exmem_pc_shadow <= u_cpu.idex_pc;
            memwb_pc_shadow <= exmem_pc_shadow;
        end
    end

    wire [31:0] debug_wb_pc       = memwb_pc_shadow;
    wire [3:0]  debug_wb_rf_we    = {4{u_cpu.memwb_valid & u_cpu.memwb_regWr}};
    wire [4:0]  debug_wb_rf_wnum  = u_cpu.memwb_waddr;
    wire [31:0] debug_wb_rf_wdata = u_cpu.memwb_wdata;

    wire [31:0] debug_wb_rf_wdata_v;
    wire [31:0] ref_wb_rf_wdata_v;
    assign debug_wb_rf_wdata_v[31:24] = debug_wb_rf_wdata[31:24] & {8{debug_wb_rf_we[3]}};
    assign debug_wb_rf_wdata_v[23:16] = debug_wb_rf_wdata[23:16] & {8{debug_wb_rf_we[2]}};
    assign debug_wb_rf_wdata_v[15: 8] = debug_wb_rf_wdata[15: 8] & {8{debug_wb_rf_we[1]}};
    assign debug_wb_rf_wdata_v[7 : 0] = debug_wb_rf_wdata[7 : 0] & {8{debug_wb_rf_we[0]}};

    integer trace_ref;
    initial begin
        trace_ref = $fopen("golden_trace.txt", "r");
        if (trace_ref == 0) begin
            $display("ERROR: cannot open golden_trace.txt");
            $finish;
        end
    end

    reg        trace_cmp_flag;
    reg [31:0] ref_wb_pc;
    reg [4:0]  ref_wb_rf_wnum;
    reg [31:0] ref_wb_rf_wdata;
    integer scan_count;
    reg debug_end;

    always @(posedge clk) begin
        #1;
        if (|debug_wb_rf_we && debug_wb_rf_wnum != 5'd0 && !debug_end && open_trace && resetn) begin
            trace_cmp_flag = 1'b0;
            while (!trace_cmp_flag && !$feof(trace_ref)) begin
                scan_count = $fscanf(trace_ref, "%h %h %h %h", trace_cmp_flag,
                                      ref_wb_pc, ref_wb_rf_wnum, ref_wb_rf_wdata);
            end
        end
    end

    assign ref_wb_rf_wdata_v[31:24] = ref_wb_rf_wdata[31:24] & {8{debug_wb_rf_we[3]}};
    assign ref_wb_rf_wdata_v[23:16] = ref_wb_rf_wdata[23:16] & {8{debug_wb_rf_we[2]}};
    assign ref_wb_rf_wdata_v[15: 8] = ref_wb_rf_wdata[15: 8] & {8{debug_wb_rf_we[1]}};
    assign ref_wb_rf_wdata_v[7 : 0] = ref_wb_rf_wdata[7 : 0] & {8{debug_wb_rf_we[0]}};

    reg debug_wb_err;
    always @(posedge clk) begin
        #2;
        if (!resetn) begin
            debug_wb_err <= 1'b0;
        end
        else if (|debug_wb_rf_we && debug_wb_rf_wnum != 5'd0 && !debug_end && open_trace) begin
            if ((debug_wb_pc !== ref_wb_pc) ||
                (debug_wb_rf_wnum !== ref_wb_rf_wnum) ||
                (debug_wb_rf_wdata_v !== ref_wb_rf_wdata_v)) begin
                $display("--------------------------------------------------------------");
                $display("[%t] Error!!!", $time);
                $display("    reference: PC = 0x%8h, wb_rf_wnum = 0x%2h, wb_rf_wdata = 0x%8h",
                         ref_wb_pc, ref_wb_rf_wnum, ref_wb_rf_wdata_v);
                $display("    mycpu    : PC = 0x%8h, wb_rf_wnum = 0x%2h, wb_rf_wdata = 0x%8h",
                         debug_wb_pc, debug_wb_rf_wnum, debug_wb_rf_wdata_v);
                $display("--------------------------------------------------------------");
                debug_wb_err <= 1'b1;
                #40;
                $finish;
            end
        end
    end

    reg [7:0] err_count;
    reg [31:0] num_data_r;
    always @(posedge clk) begin
        num_data_r <= num_data;
        if (!resetn) begin
            err_count <= 8'd0;
        end
        else if (num_data_r != num_data && num_monitor) begin
            if (num_data[7:0] != num_data_r[7:0] + 1'b1) begin
                $display("--------------------------------------------------------------");
                $display("[%t] Error(%d)!!! Occurred in number 8'd%02d Functional Test Point!",
                         $time, err_count, num_data[31:24]);
                $display("--------------------------------------------------------------");
                err_count <= err_count + 1'b1;
            end
            else if (num_data[31:24] != num_data_r[31:24] + 1'b1) begin
                $display("--------------------------------------------------------------");
                $display("[%t] Error(%d)!!! Unknown, Functional Test Point numbers are unequal!",
                         $time, err_count);
                $display("--------------------------------------------------------------");
                err_count <= err_count + 1'b1;
            end
            else begin
                $display("----[%t] Number 8'd%02d Functional Test Point PASS!!!", $time, num_data[31:24]);
            end
        end
    end

    always @(posedge clk) begin
        if (uart_valid) begin
            if (uart_data != 8'hff) begin
                $write("%c", uart_data);
            end
        end
    end

    integer cycle_count;
    initial begin
        $timeformat(-9, 0, " ns", 10);
        cycle_count = 0;
        debug_end = 1'b0;
        $display("==============================================================");
        $display("Current CPU EXP=6 trace test begin!");
    end

    always @(posedge clk) begin
        if (resetn) begin
            cycle_count <= cycle_count + 1;
            if ((cycle_count % 10000) == 0) begin
                $display("        [%t] Test is running, cycle=%0d, wb_pc=0x%8h, if_pc=0x%8h",
                         $time, cycle_count, debug_wb_pc, test_pc_cur);
            end
            if (cycle_count >= MAX_CYCLE) begin
                $display("==============================================================");
                $display("WATCHDOG TIMEOUT after %0d cycles, wb_pc=0x%8h, if_pc=0x%8h",
                         MAX_CYCLE, debug_wb_pc, test_pc_cur);
                $finish;
            end
        end
    end

    wire global_err = debug_wb_err || (err_count != 8'd0);
    wire test_end = (debug_wb_pc == END_PC) || (uart_valid && uart_data == 8'hff);
    always @(posedge clk) begin
        if (!resetn) begin
            debug_end <= 1'b0;
        end
        else if (test_end && !debug_end) begin
            debug_end <= 1'b1;
            $display("==============================================================");
            $display("Test end!");
            #40;
            $fclose(trace_ref);
            if (global_err) begin
                $display("Fail!!! Total %d errors!", err_count);
            end
            else begin
                $display("----PASS!!!");
            end
            $finish;
        end
    end
endmodule

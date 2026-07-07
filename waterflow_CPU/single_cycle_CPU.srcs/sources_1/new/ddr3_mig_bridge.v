`timescale 1ns / 1ps

module ddr3_mig_bridge_lite(
	input wire clk,
	input wire rst,
	input wire cpu_req_valid,
	output wire cpu_req_ready,
	input wire cpu_req_we,
	input wire [3:0] cpu_req_wstrb,
	input wire [31:0] cpu_req_addr,
	input wire [31:0] cpu_req_wdata,
	output reg cpu_resp_valid,
	input wire cpu_resp_ready,
	output reg [31:0] cpu_resp_rdata,
	input wire init_calib_complete,
	output reg [27:0] app_addr,
	output reg [2:0] app_cmd,
	output reg app_en,
	input wire app_rdy,
	output reg [127:0] app_wdf_data,
	output reg app_wdf_wren,
	output reg [15:0] app_wdf_mask,
	input wire app_wdf_rdy,
	input wire [127:0] app_rd_data,
	input wire app_rd_data_valid
);
	reg [1:0] state;
	reg [1:0] word_sel;
	localparam S_IDLE = 2'd0, S_WRITE = 2'd1, S_READ_CMD = 2'd2, S_READ_WAIT = 2'd3;

	assign cpu_req_ready = (state == S_IDLE) && init_calib_complete &&
		(!cpu_resp_valid || cpu_resp_ready);

	always @(posedge clk or negedge rst) begin
		if (!rst) begin
			state <= S_IDLE;
			cpu_resp_valid <= 1'b0;
			cpu_resp_rdata <= 32'h0;
			app_en <= 1'b0;
			app_wdf_wren <= 1'b0;
			app_cmd <= 3'b000;
			app_addr <= 28'h0;
			app_wdf_data <= 128'h0;
			app_wdf_mask <= 16'hffff;
			word_sel <= 2'd0;
		end else begin
			if (cpu_resp_valid && cpu_resp_ready) cpu_resp_valid <= 1'b0;
			app_en <= 1'b0;
			app_wdf_wren <= 1'b0;
			case (state)
				S_IDLE: begin
					if (cpu_req_valid && cpu_req_ready) begin
						word_sel <= cpu_req_addr[3:2];
						app_addr <= {cpu_req_addr[29:4], 4'b0000};
						if (cpu_req_we) begin
							app_cmd <= 3'b000;//ddr写命令
							app_en <= 1'b1;//命令有效
							app_wdf_wren <= 1'b1;
							app_wdf_data <= {4{cpu_req_wdata}};
							app_wdf_mask <= ~({12'h000, cpu_req_wstrb} << (cpu_req_addr[3:2] * 4));
							state <= S_WRITE;
						end else begin
							app_cmd <= 3'b001;//ddr读命令
							app_en <= 1'b1;
							state <= S_READ_CMD;
						end
					end
				end
				S_WRITE: begin
					if (app_rdy && app_wdf_rdy) begin //写需要命令、地址和数据都ready
						cpu_resp_valid <= 1'b1;
						cpu_resp_rdata <= 32'h0;
						state <= S_IDLE;
					end
				end
				S_READ_CMD: begin
					if (app_rdy) state <= S_READ_WAIT;//读只需要命令、地址ready
				end
				S_READ_WAIT: begin
					if (app_rd_data_valid) begin
						case (word_sel)//根据所选字索引选择对应字
							2'd0: cpu_resp_rdata <= app_rd_data[31:0];
							2'd1: cpu_resp_rdata <= app_rd_data[63:32];
							2'd2: cpu_resp_rdata <= app_rd_data[95:64];
							2'd3: cpu_resp_rdata <= app_rd_data[127:96];
						endcase
						cpu_resp_valid <= 1'b1;
						state <= S_IDLE;
					end
				end
			endcase
		end
	end
endmodule

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
	reg [31:0] data [0:255];
	reg [21:0] tag [0:255];
	reg valid[0:255];
	reg dirty[0:255];
	reg [2:0] state;
	reg [31:0] saved_addr, saved_wdata;
	reg [3:0] saved_wstrb;
	reg saved_we;
	wire [7:0] index = req_addr[9:2];
	wire [21:0] req_tag = req_addr[31:10];
	wire hit = valid[index] && tag[index] == req_tag;
	integer i;
	localparam S_IDLE = 3'd0, S_SEND_WB = 3'd1, S_SEND_MEM = 3'd2, S_WAIT_MEM = 3'd3, S_RESP = 3'd4;

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
			for (i = 0; i < 256; i = i + 1) begin
				valid[i] <= 1'b0;
				dirty[i] <= 1'b0;
				data[i] <= 32'h0;
				tag[i] <= 22'h0;
			end
		end else begin
			if (resp_valid && resp_ready) resp_valid <= 1'b0;
			mem_req_valid <= 1'b0;
			case (state)
				S_IDLE: begin
					if (req_valid && req_ready) begin
						saved_addr <= req_addr;
						saved_we <= req_we;
						saved_wdata <= req_wdata;
						saved_wstrb <= req_wstrb;
						if (hit) begin
							if (req_we) begin
								data[index] <= merge_word(data[index], req_wdata, req_wstrb);
								dirty[index] <= 1'b1;
								resp_rdata <= 32'h0;
							end else begin
								resp_rdata <= data[index];
							end
							resp_valid <= 1'b1;
							state <= S_RESP;
						end else begin
							if (valid[index] && dirty[index]) begin
								mem_req_valid <= 1'b1;
								mem_req_we <= 1'b1;
								mem_req_wstrb <= 4'hF;
								mem_req_addr <= {tag[index], index, 2'b00};
								mem_req_wdata <= data[index];
								state <= S_SEND_WB;
							end else begin
								mem_req_valid <= 1'b1;
								mem_req_we <= 1'b0;
								mem_req_wstrb <= 4'h0;
								mem_req_addr <= req_addr;
								mem_req_wdata <= 32'h0;
								state <= S_SEND_MEM;
							end
						end
					end
				end
				S_SEND_WB: begin
					mem_req_valid <= 1'b1;
					mem_req_we <= 1'b1;
					mem_req_wstrb <= 4'hF;
					mem_req_addr <= {tag[saved_addr[9:2]], saved_addr[9:2], 2'b00};
					mem_req_wdata <= data[saved_addr[9:2]];
					if (mem_req_ready) state <= S_SEND_MEM;
				end
				S_SEND_MEM: begin
					mem_req_valid <= 1'b1;
					mem_req_we <= 1'b0;
					mem_req_wstrb <= 4'h0;
					mem_req_addr <= saved_addr;
					mem_req_wdata <= 32'h0;
					if (mem_req_ready) state <= S_WAIT_MEM;
				end
				S_WAIT_MEM: begin
					if (mem_resp_valid) begin
						tag[saved_addr[9:2]] <= saved_addr[31:10];
						valid[saved_addr[9:2]] <= 1'b1;
						if (saved_we) begin
							data[saved_addr[9:2]] <= merge_word(mem_resp_rdata, saved_wdata, saved_wstrb);
							dirty[saved_addr[9:2]] <= 1'b1;
							resp_rdata <= 32'h0;
						end else begin
							data[saved_addr[9:2]] <= mem_resp_rdata;
							dirty[saved_addr[9:2]] <= 1'b0;
							resp_rdata <= mem_resp_rdata;
						end
						resp_valid <= 1'b1;
						state <= S_RESP;
					end
				end
				S_RESP: begin
					if (!resp_valid || resp_ready) state <= S_IDLE;
				end
			endcase
		end
	end
endmodule

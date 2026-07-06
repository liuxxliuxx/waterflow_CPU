module reg_32bit(
    input         clk,
    input         rst,
    input  [ 4:0] raddr1,
    output [31:0] rdata1,
    input  [ 4:0] raddr2,
    output [31:0] rdata2,
    input         wen,
    input  [ 4:0] waddr,
    input  [31:0] wdata,
    input  [ 4:0] test_addr,
    output [31:0] test_data
);
    reg [31:0] rf [31:0];
    reg [5:0]  i;
    always @(posedge clk or negedge rst) begin
        if(!rst) begin
            for(i=0;i<32;i=i+1) begin
                rf[i] <= 32'd0;
            end
        end
        else begin
            if (wen && (waddr != 5'd0)) begin
                rf[waddr] <= wdata;
            end
        end
        
    end
    assign rdata1=rf[raddr1];
    assign rdata2=rf[raddr2];
    assign test_data=rf[test_addr];
endmodule
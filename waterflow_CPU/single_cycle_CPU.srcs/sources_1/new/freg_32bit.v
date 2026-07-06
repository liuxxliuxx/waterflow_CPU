module freg_32bit(
    input        clk,
    input        rst,
    input [4:0]  raddr1,
    input [4:0]  raddr2,
    output[31:0] rdata1,
    output[31:0] rdata2,
    
    input        wen,
    input [4:0]  waddr,
    input [31:0] wdata,
    input [4:0]  test_addr,
    output[31:0] test_data
    );
    
    reg[31:0] frf[31:0];
    integer i;
    
    always @(posedge clk or negedge rst) begin
        if(!rst) begin
            for(i=0;i<32;i=i+1) begin
                frf[i] <= 32'd0;
            end
        end
        else if(wen) begin
            frf[waddr] <= wdata;
        end
    end
    
    assign rdata1    = frf[raddr1];
    assign rdata2    = frf[raddr2];
    assign test_data = frf[test_addr];
    
endmodule

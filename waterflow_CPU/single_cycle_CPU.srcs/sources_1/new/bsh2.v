module bsh2(
    input     [31:0] A,
    input            en,
    input            dir,
    input            issign,
    output reg[31:0] res
    );
    always @(*) begin
        if(!en) begin
            res = A;
        end
        else begin
            if(dir) begin
                if(issign) begin
                    res = {{2{A[31]}},A[31:2]};
                end
                else begin
                    res = {2'b0,A[31:2]};
                end
            end
            else begin
                res = {A[29:0],2'b0};
            end
        end
    end
endmodule

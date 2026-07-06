module bsh16(
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
                    res = {{16{A[31]}},A[31:16]};
                end
                else begin
                    res = {16'b0,A[31:16]};
                end
            end
            else begin
                res = {A[15:0],16'b0};
            end
        end
    end
endmodule

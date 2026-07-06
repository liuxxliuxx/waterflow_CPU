module bsh4(
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
                    res = {{4{A[31]}},A[31:4]};
                end
                else begin
                    res = {4'b0,A[31:4]};
                end
            end
            else begin
                res = {A[27:0],4'b0};
            end
        end
    end
endmodule

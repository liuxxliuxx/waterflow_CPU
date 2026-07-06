module bsh1(
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
                    res = {A[31],A[31:1]};
                end
                else begin
                    res = {1'b0,A[31:1]};
                end
            end
            else begin
                res = {A[30:0],1'b0};
            end
        end
    end
endmodule

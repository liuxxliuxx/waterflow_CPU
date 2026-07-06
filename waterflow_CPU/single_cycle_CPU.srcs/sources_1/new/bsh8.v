module bsh8(
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
                    res = {{8{A[31]}},A[31:8]};
                end
                else begin
                    res = {8'b0,A[31:8]};
                end
            end
            else begin
                res = {A[23:0],8'b0};
            end
        end
    end
endmodule

module adder
(
    input   wire    [31:0]   A,
    input   wire    [31:0]   B,
    input   wire             cin,
    output  wire    [31:0]   Sum,
    output  wire             cout
);
    wire [31:0] p;
    wire [31:0] g;
    wire [31:0] c;
    
    wire [9:0]  P;
    wire [9:0]  G;
    
    wire ac;
    
    assign c[0] = cin;
    assign p = A^B;
    assign g = A&B;
    
    adder_4bit add0_0(.p(p[3:0]),.g(g[3:0]),.cin(c[0]),.P(P[0]),.G(G[0]),.cout(c[3:1]));
    adder_4bit add0_1(.p(p[7:4]),.g(g[7:4]),.cin(c[4]),.P(P[1]),.G(G[1]),.cout(c[7:5]));
    adder_4bit add0_2(.p(p[11:8]),.g(g[11:8]),.cin(c[8]),.P(P[2]),.G(G[2]),.cout(c[11:9]));
    adder_4bit add0_3(.p(p[15:12]),.g(g[15:12]),.cin(c[12]),.P(P[3]),.G(G[3]),.cout(c[15:13]));
    adder_4bit add0_4(.p(P[3:0]),.g(G[3:0]),.cin(c[0]),.P(P[4]),.G(G[4]),.cout({c[12],c[8],c[4]}));
    
    adder_4bit add1_0(.p(p[19:16]),.g(g[19:16]),.cin(c[16]),.P(P[5]),.G(G[5]),.cout(c[19:17]));
    adder_4bit add1_1(.p(p[23:20]),.g(g[23:20]),.cin(c[20]),.P(P[6]),.G(G[6]),.cout(c[23:21]));
    adder_4bit add1_2(.p(p[27:24]),.g(g[27:24]),.cin(c[24]),.P(P[7]),.G(G[7]),.cout(c[27:25]));
    adder_4bit add1_3(.p(p[31:28]),.g(g[31:28]),.cin(c[28]),.P(P[8]),.G(G[8]),.cout(c[31:29]));
    adder_4bit add1_4(.p(P[8:5]),.g(G[8:5]),.cin(c[16]),.P(P[9]),.G(G[9]),.cout({c[28],c[24],c[20]}));
    
    adder_4bit add2(.p({2'b00,P[9],P[4]}),.g({2'b00,G[9],G[4]}),.cin(c[0]),.P(),.G(),.cout({ac,cout,c[16]}));
    
    assign Sum[31:0] = p^c;
    
endmodule

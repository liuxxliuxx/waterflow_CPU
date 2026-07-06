module ram(
    input        clk,
    input[15:0]  ram_addr,
    input[31:0]  ram_wdata,
    input        ram_wen,
    output[31:0] ram_data
    );
    
    bram u_bram(
        .clka(clk),
        .wea({ram_wen}),
        .addra(ram_addr),
        .dina(ram_wdata),
        .douta(ram_data)
    );
endmodule

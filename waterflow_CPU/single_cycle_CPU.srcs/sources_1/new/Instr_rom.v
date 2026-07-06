module Instr_rom(
    input[15:0] addr,
    output[31:0] data
    );
    dist_rom u_rom(
        .a(addr),
        .spo(data)
    );
endmodule

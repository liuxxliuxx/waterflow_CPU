`timescale 1ns / 1ps
`default_nettype none

module clk_ref_200_gen(
    input wire clk_in,
    input wire rst,
    output wire clk_out,
    output wire locked
);
    wire clkfb;
    wire clkfb_buf;
    wire clkout0;

    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT_F(8.000),
        .CLKFBOUT_PHASE(0.000),
        .CLKIN1_PERIOD(10.000),
        .CLKOUT0_DIVIDE_F(4.000),
        .CLKOUT0_DUTY_CYCLE(0.500),
        .CLKOUT0_PHASE(0.000),
        .DIVCLK_DIVIDE(1),
        .REF_JITTER1(0.010),
        .STARTUP_WAIT("FALSE")
    ) u_mmcm (
        .CLKFBOUT(clkfb),
        .CLKFBOUTB(),
        .CLKOUT0(clkout0),
        .CLKOUT0B(),
        .CLKOUT1(),
        .CLKOUT1B(),
        .CLKOUT2(),
        .CLKOUT2B(),
        .CLKOUT3(),
        .CLKOUT3B(),
        .CLKOUT4(),
        .CLKOUT5(),
        .CLKOUT6(),
        .LOCKED(locked),
        .CLKFBIN(clkfb_buf),
        .CLKIN1(clk_in),
        .PWRDWN(1'b0),
        .RST(rst)
    );

    BUFG u_clkfb_bufg (
        .I(clkfb),
        .O(clkfb_buf)
    );

    BUFG u_clkout_bufg (
        .I(clkout0),
        .O(clk_out)
    );
endmodule

`default_nettype wire

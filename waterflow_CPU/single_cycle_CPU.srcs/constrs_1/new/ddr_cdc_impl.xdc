# ddr_cdc_bridge is the explicit handshake crossing between the 50 MHz SoC
# domain and the MIG UI domain. clk_pll_i exists only after the MIG DCP is
# linked, so this constraint is implementation-only in project mode.
set_clock_groups -asynchronous \
    -group [get_clocks {clk_out1_clk_wiz_0}] \
    -group [get_clocks {clk_pll_i}]

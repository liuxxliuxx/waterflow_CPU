# Project-mode RTL synthesis runs before the scoped MIG input-clock constraint
# is linked into the top-level design. Supply the same 100 MHz board clock here
# only for synthesis; implementation inherits it from the synthesized DCP.
create_clock -name sys_clk_i -period 10.000 [get_ports {sys_clk_i}]

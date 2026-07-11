# FPGA-A7-PRJ-UDB board I/O for soc_top.
# DDR3 pin, electrical and timing constraints are supplied by mig_7series_0.

set_property PACKAGE_PIN AC19 [get_ports {sys_clk_i}]
set_property IOSTANDARD LVCMOS33 [get_ports {sys_clk_i}]

# soc_vga_clk_div divides the 100 MHz board clock by four.  This is the
# 25 MHz clock domain for CPU, caches, MMIO, NAND boot, and VGA.
create_generated_clock -name soc_clk_25 -source [get_ports {sys_clk_i}] \
    -divide_by 4 [get_pins {u_vga_clk_div/u_pix_clk_bufg/O}]

# The DDR UI clock is generated inside MIG.  ddr_cdc_bridge explicitly
# synchronizes the two domains, so timing must not analyze them as related.
set ddr_ui_clks [get_clocks -quiet -of_objects [get_nets -quiet {ddr_ui_clk}]]
if {[llength $ddr_ui_clks] == 0} {
    set ddr_ui_clks [get_clocks -quiet -of_objects \
        [get_pins -quiet {u_mem_subsystem/u_ddr3_bridge/ui_clk}]]
}
if {[llength $ddr_ui_clks] != 0} {
    set_clock_groups -asynchronous \
        -group [get_clocks {soc_clk_25}] \
        -group $ddr_ui_clks
}

set_property PACKAGE_PIN Y3 [get_ports {rst_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {rst_n}]

set_property PACKAGE_PIN V19 [get_ports {nand_cle}]
set_property PACKAGE_PIN W20 [get_ports {nand_ale}]
set_property PACKAGE_PIN AB24 [get_ports {nand_ce_n}]
set_property PACKAGE_PIN AA24 [get_ports {nand_re_n}]
set_property PACKAGE_PIN AA22 [get_ports {nand_we_n}]
set_property PACKAGE_PIN AA25 [get_ports {nand_rdy}]

set_property PACKAGE_PIN AC24 [get_ports {nand_d[0]}]
set_property PACKAGE_PIN W21 [get_ports {nand_d[1]}]
set_property PACKAGE_PIN U20 [get_ports {nand_d[2]}]
set_property PACKAGE_PIN U19 [get_ports {nand_d[3]}]
set_property PACKAGE_PIN V18 [get_ports {nand_d[4]}]
set_property PACKAGE_PIN Y21 [get_ports {nand_d[5]}]
set_property PACKAGE_PIN Y20 [get_ports {nand_d[6]}]
set_property PACKAGE_PIN W19 [get_ports {nand_d[7]}]

set_property IOSTANDARD LVCMOS33 [get_ports {nand_cle nand_ale nand_ce_n nand_re_n nand_we_n nand_rdy nand_d[*]}]

set_property PACKAGE_PIN H19 [get_ports {uart_tx}]
set_property PACKAGE_PIN F23 [get_ports {uart_rx}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_tx uart_rx}]

set_property PACKAGE_PIN H7 [get_ports {led[0]}]
set_property PACKAGE_PIN D5 [get_ports {led[1]}]
set_property PACKAGE_PIN A3 [get_ports {led[2]}]
set_property PACKAGE_PIN A5 [get_ports {led[3]}]
set_property PACKAGE_PIN A4 [get_ports {led[4]}]
set_property PACKAGE_PIN F7 [get_ports {led[5]}]
set_property PACKAGE_PIN G8 [get_ports {led[6]}]
set_property PACKAGE_PIN H8 [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

# FPGA-A7-PRJ-UDB board I/O for soc_top.
# DDR3 pin, electrical and timing constraints are supplied by mig_7series_0.

set_property PACKAGE_PIN AC19 [get_ports {sys_clk_i}]
# The MIG-generated XDC declares LVCMOS25, but this board's Bank 12 VCCO is
# 3.3 V. Apply the board-specific standard after the EARLY MIG constraints.
set_property IOSTANDARD LVCMOS33 [get_ports {sys_clk_i}]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# soc_vga_clk_div divides the 100 MHz board clock by four.  This is the
# 25 MHz clock domain for CPU, caches, MMIO, NAND boot, and VGA. Project-mode
# synthesis gets the master clock from soc_clock_synth.xdc; implementation and
# the non-project flow get the equivalent 100 MHz master from the linked MIG.
create_generated_clock -name soc_clk_25 -source [get_ports {sys_clk_i}] \
    -divide_by 4 [get_pins {u_vga_clk_div/u_pix_clk_bufg/O}]

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

# VGA, fixed 640x480 at a 25 MHz pixel clock.
set_property PACKAGE_PIN T3 [get_ports {vga_r[0]}]
set_property PACKAGE_PIN T2 [get_ports {vga_r[1]}]
set_property PACKAGE_PIN U2 [get_ports {vga_r[2]}]
set_property PACKAGE_PIN U4 [get_ports {vga_r[3]}]
set_property PACKAGE_PIN R2 [get_ports {vga_g[0]}]
set_property PACKAGE_PIN R1 [get_ports {vga_g[1]}]
set_property PACKAGE_PIN U1 [get_ports {vga_g[2]}]
set_property PACKAGE_PIN R5 [get_ports {vga_g[3]}]
set_property PACKAGE_PIN P5 [get_ports {vga_b[0]}]
set_property PACKAGE_PIN N1 [get_ports {vga_b[1]}]
set_property PACKAGE_PIN P1 [get_ports {vga_b[2]}]
set_property PACKAGE_PIN P3 [get_ports {vga_b[3]}]
set_property PACKAGE_PIN U5 [get_ports {vga_hsync}]
set_property PACKAGE_PIN U6 [get_ports {vga_vsync}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[*] vga_g[*] vga_b[*] vga_hsync vga_vsync}]

# Receive-only PS/2. The board provides the required pull-up resistors.
set_property PACKAGE_PIN Y2 [get_ports {ps2_clk}]
set_property PACKAGE_PIN AD1 [get_ports {ps2_dat}]
set_property IOSTANDARD LVCMOS33 [get_ports {ps2_clk ps2_dat}]

# The sixteen discrete LEDs are active low at the FPGA pins. soc_top converts
# the MMIO register's logical 1=on representation to this physical polarity.
set_property PACKAGE_PIN H7 [get_ports {led[0]}]
set_property PACKAGE_PIN D5 [get_ports {led[1]}]
set_property PACKAGE_PIN A3 [get_ports {led[2]}]
set_property PACKAGE_PIN A5 [get_ports {led[3]}]
set_property PACKAGE_PIN A4 [get_ports {led[4]}]
set_property PACKAGE_PIN F7 [get_ports {led[5]}]
set_property PACKAGE_PIN G8 [get_ports {led[6]}]
set_property PACKAGE_PIN H8 [get_ports {led[7]}]
set_property PACKAGE_PIN J8 [get_ports {led[8]}]
set_property PACKAGE_PIN J23 [get_ports {led[9]}]
set_property PACKAGE_PIN J26 [get_ports {led[10]}]
set_property PACKAGE_PIN G9 [get_ports {led[11]}]
set_property PACKAGE_PIN J19 [get_ports {led[12]}]
set_property PACKAGE_PIN H23 [get_ports {led[13]}]
set_property PACKAGE_PIN J21 [get_ports {led[14]}]
set_property PACKAGE_PIN K23 [get_ports {led[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

# Eight common-cathode seven-segment digits. seg_csn is active low; seg uses
# active-high A, B, C, D, E, F, G, DP bits in that order.
set_property PACKAGE_PIN D3 [get_ports {seg_csn[0]}]
set_property PACKAGE_PIN D25 [get_ports {seg_csn[1]}]
set_property PACKAGE_PIN D26 [get_ports {seg_csn[2]}]
set_property PACKAGE_PIN E25 [get_ports {seg_csn[3]}]
set_property PACKAGE_PIN E26 [get_ports {seg_csn[4]}]
set_property PACKAGE_PIN G25 [get_ports {seg_csn[5]}]
set_property PACKAGE_PIN G26 [get_ports {seg_csn[6]}]
set_property PACKAGE_PIN H26 [get_ports {seg_csn[7]}]
set_property PACKAGE_PIN A2 [get_ports {seg[0]}]
set_property PACKAGE_PIN D4 [get_ports {seg[1]}]
set_property PACKAGE_PIN E5 [get_ports {seg[2]}]
set_property PACKAGE_PIN B4 [get_ports {seg[3]}]
set_property PACKAGE_PIN B2 [get_ports {seg[4]}]
set_property PACKAGE_PIN E6 [get_ports {seg[5]}]
set_property PACKAGE_PIN C3 [get_ports {seg[6]}]
set_property PACKAGE_PIN C4 [get_ports {seg[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg_csn[*] seg[*]}]

# Two common-cathode dual-color LEDs. These pins are active high. The board
# documentation notes that the R/G signal names are physically reversed.
set_property PACKAGE_PIN G7 [get_ports {led_dual_r[0]}]
set_property PACKAGE_PIN F8 [get_ports {led_dual_g[0]}]
set_property PACKAGE_PIN B5 [get_ports {led_dual_r[1]}]
set_property PACKAGE_PIN D6 [get_ports {led_dual_g[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_dual_r[*] led_dual_g[*]}]

# Asynchronous board inputs have no phase relationship to sys_clk_i. PS/2 and
# UART are synchronized by their receive logic; NAND data/ready are sampled
# only after the controller's protocol wait states. rst_n is an asynchronous
# board control. Cut only paths launched at these input ports so all internal
# synchronous paths remain timed.
set_false_path -from [get_ports {rst_n}]
set_false_path -from [get_ports {ps2_clk ps2_dat uart_rx}]
set_false_path -from [get_ports {nand_rdy nand_d[*]}]

# These outputs have no external capture clock that can be expressed as an
# FPGA timing relationship. Their protocol timing is generated internally;
# static indicators likewise have no receiving clock. Cut only the top-level
# output endpoints rather than inventing device delays that are not specified
# by the board documentation.
set_false_path -to [get_ports {uart_tx}]
set_false_path -to [get_ports {vga_r[*] vga_g[*] vga_b[*] vga_hsync vga_vsync}]
set_false_path -to [get_ports {led[*] led_dual_r[*] led_dual_g[*]}]
set_false_path -to [get_ports {seg_csn[*] seg[*]}]
set_false_path -to [get_ports {nand_cle nand_ale nand_ce_n nand_re_n nand_we_n nand_d[*]}]
# DDR3 reset is an asynchronous static control, not a clock-captured data pin.
set_false_path -to [get_ports {ddr3_reset_n}]

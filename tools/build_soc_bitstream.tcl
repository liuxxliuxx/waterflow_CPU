set root [file normalize [file join [file dirname [info script]] ..]]
set rtl_dir [file join $root waterflow_CPU single_cycle_CPU.srcs sources_1 new]
set ip_dir [file join $root waterflow_CPU single_cycle_CPU.srcs sources_1 ip mig_7series_0]
set xci [file join $ip_dir mig_7series_0.xci]
set board_xdc [file join $root waterflow_CPU single_cycle_CPU.srcs constrs_1 new xdcc.xdc]
set mig_xdc [file join $ip_dir mig_7series_0 user_design constraints mig_7series_0.xdc]
set out_dir [file join $root bitstream]
set report_dir [file join $root reports]

file mkdir $out_dir
file mkdir $report_dir

set_part xc7a200tfbg676-1
read_ip $xci
generate_target all [get_ips mig_7series_0]
set caller_dir [pwd]
cd $rtl_dir
read_verilog -sv [glob -nocomplain *.v]
cd $caller_dir

synth_design -top soc_top -part xc7a200tfbg676-1
read_xdc $board_xdc
read_xdc $mig_xdc

opt_design
place_design
phys_opt_design
route_design
report_utilization -file [file join $report_dir soc_top_utilization_routed.rpt]
report_timing_summary -file [file join $report_dir soc_top_timing_summary_routed.rpt]
report_drc -file [file join $report_dir soc_top_drc_routed.rpt]
write_bitstream -force [file join $out_dir soc_top.bit]
puts "SOC_TOP_BITSTREAM_PASS"

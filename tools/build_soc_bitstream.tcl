# Pass the repository through a temporary drive mapping on Windows. Vivado
# 2019.2 otherwise drops the Desktop path component while normalizing this
# workspace location.
if {[llength $argv] != 1} {
    puts stderr "usage: vivado -mode batch -source tools/build_soc_bitstream.tcl -tclargs <repo-root>"
    exit 2
}
set root [lindex $argv 0]
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
set rtl_files [glob -nocomplain -directory $rtl_dir *.v]
if {[llength $rtl_files] == 0} {
    puts stderr "no RTL files found in $rtl_dir"
    exit 2
}
read_verilog -sv $rtl_files

synth_design -top soc_top -part xc7a200tfbg676-1
# MIG marks its clock constraints EARLY in project mode. Preserve that order
# here so xdcc.xdc can see clk_pll_i and cut the explicit DDR CDC bridge.
read_xdc $mig_xdc
read_xdc $board_xdc

set soc_clock [get_clocks -quiet {soc_clk_25}]
set ddr_ui_clock [get_clocks -quiet {clk_pll_i}]
if {[llength $soc_clock] == 0 || [llength $ddr_ui_clock] == 0} {
    error "Could not resolve soc_clk_25 and clk_pll_i for the DDR CDC constraint"
}
set_clock_groups -asynchronous -group $soc_clock -group $ddr_ui_clock

opt_design
place_design
phys_opt_design
route_design
report_utilization -file [file join $report_dir soc_top_utilization_routed.rpt]
report_timing_summary -file [file join $report_dir soc_top_timing_summary_routed.rpt]
report_drc -file [file join $report_dir soc_top_drc_routed.rpt]

# Fail closed on missing timing intent. check_timing marks no-clock registers,
# unconstrained internal endpoints, disconnected generated clocks, and missing
# I/O delay/exception coverage as HIGH. Keep its report as a build artifact and
# reject every HIGH finding before a bitstream can replace the previous one.
set check_timing_file [file join $report_dir soc_top_check_timing_routed.rpt]
check_timing -verbose -file $check_timing_file
set check_timing_handle [open $check_timing_file r]
set check_timing_text [read $check_timing_handle]
close $check_timing_handle
set check_timing_high_issues {}
foreach line [split $check_timing_text "\n"] {
    if {[string first "(HIGH)" $line] >= 0} {
        lappend check_timing_high_issues [string trim $line]
    }
}
if {[llength $check_timing_high_issues] != 0} {
    error [format "check_timing reported HIGH issue(s): %s" \
        [join $check_timing_high_issues " | "]]
}

set drc_errors [get_drc_violations -quiet -filter {SEVERITY == Error}]
if {[llength $drc_errors] != 0} {
    error [format "DRC reported %d error(s)" [llength $drc_errors]]
}

set setup_paths [get_timing_paths -quiet -delay_type max -max_paths 1 -nworst 1]
set hold_paths [get_timing_paths -quiet -delay_type min -max_paths 1 -nworst 1]
if {[llength $setup_paths] == 0 || [llength $hold_paths] == 0} {
    error "No setup/hold timing paths found"
}
set wns [get_property SLACK [lindex $setup_paths 0]]
set whs [get_property SLACK [lindex $hold_paths 0]]
puts [format "ROUTED_TIMING WNS=%.3f ns WHS=%.3f ns" $wns $whs]
if {$wns < 0.0 || $whs < 0.0} {
    error [format "Timing not met: WNS=%.3f ns WHS=%.3f ns" $wns $whs]
}
write_bitstream -force [file join $out_dir soc_top.bit]
puts "SOC_TOP_BITSTREAM_PASS"

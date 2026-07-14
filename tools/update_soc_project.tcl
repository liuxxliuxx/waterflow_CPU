if {[llength $argv] != 1} {
    puts stderr "usage: vivado -mode batch -source update_soc_project.tcl -tclargs <project.xpr>"
    exit 2
}

set project_path [file normalize [lindex $argv 0]]
set project_dir [file dirname $project_path]
set rtl_dir [file join $project_dir single_cycle_CPU.srcs sources_1 new]
set sim_dir [file join $project_dir single_cycle_CPU.srcs sim_1 new]

open_project $project_path

foreach project_file [get_files -quiet -all] {
    if {[string match {*boot_image_rom.v} $project_file]} {
        remove_files $project_file
    }
}

# Project synthesis needs a top-level master clock before the board XDC creates
# soc_clk_25. The MIG UI clock exists only after link_design, so its CDC clock
# group is kept in a separate implementation-only constraint file.
set constr_dir [file join $project_dir single_cycle_CPU.srcs constrs_1 new]
set synth_clock_xdc [file join $constr_dir soc_clock_synth.xdc]
set board_xdc [file join $constr_dir xdcc.xdc]
set cdc_impl_xdc [file join $constr_dir ddr_cdc_impl.xdc]
foreach xdc_file [list $synth_clock_xdc $board_xdc $cdc_impl_xdc] {
    set xdc_object [get_files -quiet -all "*[file tail $xdc_file]"]
    if {[llength $xdc_object] == 0} {
        add_files -fileset constrs_1 -norecurse $xdc_file
        set xdc_object [get_files -quiet -all "*[file tail $xdc_file]"]
    }
    if {[llength $xdc_object] != 1} {
        error "Could not resolve exactly one project constraint for $xdc_file"
    }
}

set synth_clock_object [get_files -all "*[file tail $synth_clock_xdc]"]
set board_object [get_files -all "*[file tail $board_xdc]"]
set cdc_impl_object [get_files -all "*[file tail $cdc_impl_xdc]"]
set_property USED_IN_SYNTHESIS true $synth_clock_object
set_property USED_IN_IMPLEMENTATION false $synth_clock_object
set_property PROCESSING_ORDER EARLY $synth_clock_object
set_property USED_IN_SYNTHESIS true $board_object
set_property USED_IN_IMPLEMENTATION true $board_object
set_property PROCESSING_ORDER LATE $board_object
set_property USED_IN_SYNTHESIS false $cdc_impl_object
set_property USED_IN_IMPLEMENTATION true $cdc_impl_object
set_property PROCESSING_ORDER LATE $cdc_impl_object
puts "PROJECT_CONSTRAINTS [get_files -of_objects [get_filesets constrs_1]]"

foreach file_name {ddr_cdc_bridge.v nand_boot_loader.v sevenseg_scan.v soc_top.v} {
    set file_path [file join $rtl_dir $file_name]
    if {[llength [get_files -quiet $file_path]] == 0} {
        add_files -norecurse $file_path
    }
}

set old_sim [file join $sim_dir sim.v]
if {[llength [get_files -quiet $old_sim]] != 0} {
    remove_files $old_sim
}

foreach file_name {
    nand_boot_loader_tb.v
    nand_boot_loader_timeout_tb.v
    nand_boot_loader_ddr_timeout_tb.v
    boot_selftest_failure_tb.v
    ddr_cdc_bridge_tb.v
    mmio_peripheral_regs_tb.v
    ps2_raw_tb.v
    sevenseg_scan_tb.v
    uart_tx_simple_tb.v
    vga_text_tb.v
} {
    set file_path [file join $sim_dir $file_name]
    if {[llength [get_files -quiet $file_path]] == 0} {
        add_files -fileset sim_1 -norecurse $file_path
    }
}

set_property top soc_top [get_filesets sources_1]
set_property top nand_boot_loader_tb [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
close_project
puts "SOC_PROJECT_UPDATE_PASS"

if {[llength $argv] != 1} {
    puts stderr "usage: vivado -mode batch -source update_soc_project.tcl -tclargs <project.xpr>"
    exit 2
}

set project_path [file normalize [lindex $argv 0]]
set project_dir [file dirname $project_path]
set rtl_dir [file join $project_dir single_cycle_CPU.srcs sources_1 new]
set sim_dir [file join $project_dir single_cycle_CPU.srcs sim_1 new]

open_project $project_path

foreach file_name {nand_boot_loader.v soc_top.v} {
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
save_project
close_project

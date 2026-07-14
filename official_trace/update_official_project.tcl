set official_root "C:/Users/liuxx/Desktop/small_term/lab6-23/cdp_ede_local-master/cdp_ede_local-master/mycpu_env"
set project_file "$official_root/soc_verify/soc_bram/run_vivado/project/loongson.xpr"
set mycpu_dir    "$official_root/myCPU"

open_project $project_file

# Remove all old myCPU entries. The supplied project contains stale paths from
# an earlier CPU version; keeping them causes missing-file and duplicate-module
# errors after the current RTL is installed.
set old_cpu_files [get_files -quiet -filter {NAME =~ "*/myCPU/*"}]
if {[llength $old_cpu_files] != 0} {
    remove_files $old_cpu_files
}

set cpu_files [glob -nocomplain "$mycpu_dir/*.v"]
if {[llength $cpu_files] == 0} {
    error "No Verilog files found in $mycpu_dir"
}
add_files -norecurse $cpu_files

set header_files [glob -nocomplain "$mycpu_dir/*.vh"]
if {[llength $header_files] != 0} {
    add_files -norecurse $header_files
}

set_property top soc_lite_top [get_filesets sources_1]
set_property top tb_top       [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
close_project

puts "Official project source list updated: $project_file"

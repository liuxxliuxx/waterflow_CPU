set official_root "C:/Users/liuxx/Desktop/small_term/lab6-23/cdp_ede_local-master/cdp_ede_local-master/mycpu_env"
set project_file "$official_root/soc_verify/soc_bram/run_vivado/project/loongson.xpr"

open_project $project_file
set_property top soc_lite_top [get_filesets sources_1]
set_property top tb_top       [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

launch_simulation
run 120 us
puts "OFFICIAL_PROJECT_STATUS_WINDOW_FINISHED"
close_sim
close_project

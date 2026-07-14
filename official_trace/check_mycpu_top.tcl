set project_file "C:/Users/liuxx/Desktop/small_term/lab6-23/cdp_ede_local-master/cdp_ede_local-master/mycpu_env/soc_verify/soc_bram/run_vivado/project/loongson.xpr"

open_project $project_file
set_property top soc_lite_top [get_filesets sources_1]
set_property top tb_top       [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
launch_simulation
puts "MYCPU_TOP_ELABORATION_OK"
close_sim
close_project

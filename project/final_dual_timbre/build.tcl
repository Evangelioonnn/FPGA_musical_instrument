set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir final_dual_timbre.gprj]
set_option -top_module final_dual_top
set_option -output_base_name final_dual_timbre
run all

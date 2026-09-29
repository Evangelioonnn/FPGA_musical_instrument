set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir ram8.gprj]
set_option -top_module ram8_top
set_option -output_base_name ram8
run all

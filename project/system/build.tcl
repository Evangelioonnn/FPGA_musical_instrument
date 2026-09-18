set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir system.gprj]
set_option -top_module system_top
set_option -output_base_name system
run all

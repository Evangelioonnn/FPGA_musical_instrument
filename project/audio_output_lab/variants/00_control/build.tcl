set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir 00_control.gprj]
set_option -top_module output_00_control
set_option -output_base_name 00_control
run all

set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir five_capacity16.gprj]
set_option -top_module five_capacity16
set_option -output_base_name five_capacity16
run all

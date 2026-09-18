set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir capacity16.gprj]
set_option -top_module capacity16_top
set_option -output_base_name capacity16
run all

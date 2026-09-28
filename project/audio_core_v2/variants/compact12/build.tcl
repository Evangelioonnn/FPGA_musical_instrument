set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir compact12.gprj]
set_option -top_module compact12_top
set_option -output_base_name compact12
run all

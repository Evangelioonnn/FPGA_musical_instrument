set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir piano32.gprj]
set_option -top_module piano32_top
set_option -output_base_name piano32
run all

set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir piano16.gprj]
set_option -top_module piano16_top
set_option -output_base_name piano16
run all

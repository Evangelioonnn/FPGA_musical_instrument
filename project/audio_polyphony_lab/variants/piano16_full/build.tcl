set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir piano16_full.gprj]
set_option -top_module piano16_full_top
set_option -output_base_name piano16_full
run all

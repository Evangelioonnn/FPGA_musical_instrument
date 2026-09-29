set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir lab_a4.gprj]
set_option -top_module lab_a4_top
set_option -output_base_name lab_a4
run all

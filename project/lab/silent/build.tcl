set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir lab_silent.gprj]
set_option -top_module lab_silent_top
set_option -output_base_name lab_silent
run all

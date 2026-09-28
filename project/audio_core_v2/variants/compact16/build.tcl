set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir compact16.gprj]
set_option -top_module compact16_top
set_option -output_base_name compact16
run all

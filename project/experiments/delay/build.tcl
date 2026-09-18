set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir delay.gprj]
set_option -top_module delay_top
set_option -output_base_name delay
run all

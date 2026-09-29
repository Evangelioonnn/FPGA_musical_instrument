set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir resource_sine.gprj]
set_option -top_module resource_duplicated_sine_top
set_option -output_base_name resource_sine_duplicated
run all

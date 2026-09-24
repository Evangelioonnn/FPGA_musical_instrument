set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir resource_shared_sine.gprj]
set_option -top_module resource_shared_sine_top
set_option -output_base_name resource_shared_sine
run all

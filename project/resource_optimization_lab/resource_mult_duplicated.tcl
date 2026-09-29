set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir resource_mult.gprj]
set_option -top_module resource_duplicated_mult_top
set_option -output_base_name resource_mult_duplicated
run all

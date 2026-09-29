set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir resource_optimization_lab.gprj]
set_option -top_module resource_pruned_top
set_option -output_base_name resource_pruned
run all

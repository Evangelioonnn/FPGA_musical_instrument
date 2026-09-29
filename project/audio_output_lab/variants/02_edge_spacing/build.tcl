set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir 02_edge_spacing.gprj]
set_option -top_module output_02_edge_spacing
set_option -output_base_name 02_edge_spacing
run all

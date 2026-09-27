set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir five_00_reference.gprj]
set_option -top_module five_00_reference
set_option -output_base_name five_00_reference
run all

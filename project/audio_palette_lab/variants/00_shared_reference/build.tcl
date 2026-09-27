set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir 00_shared_reference.gprj]
set_option -top_module palette_00_shared_reference
set_option -output_base_name 00_shared_reference
run all

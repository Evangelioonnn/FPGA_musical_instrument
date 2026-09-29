set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir 01_piano_precision.gprj]
set_option -top_module palette_01_piano_precision
set_option -output_base_name 01_piano_precision
run all

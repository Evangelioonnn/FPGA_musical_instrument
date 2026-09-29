set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir 01_piano_headroom.gprj]
set_option -top_module output_01_piano_headroom
set_option -output_base_name 01_piano_headroom
run all

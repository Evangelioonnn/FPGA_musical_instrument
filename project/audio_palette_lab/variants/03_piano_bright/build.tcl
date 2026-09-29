set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir 03_piano_bright.gprj]
set_option -top_module palette_03_piano_bright
set_option -output_base_name 03_piano_bright
run all

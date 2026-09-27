set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir 02_piano_soft.gprj]
set_option -top_module palette_02_piano_soft
set_option -output_base_name 02_piano_soft
run all

set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir pool8.gprj]
set_option -top_module pool8_top
set_option -output_base_name pool8
run all

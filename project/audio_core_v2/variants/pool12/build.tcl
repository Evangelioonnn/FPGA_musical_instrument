set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir pool12.gprj]
set_option -top_module pool12_top
set_option -output_base_name pool12
run all

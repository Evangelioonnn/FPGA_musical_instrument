set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir 06_pluck_warm.gprj]
set_option -top_module palette_06_pluck_warm
set_option -output_base_name 06_pluck_warm
run all

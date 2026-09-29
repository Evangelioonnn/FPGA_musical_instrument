set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir 05_pluck_detail.gprj]
set_option -top_module palette_05_pluck_detail
set_option -output_base_name 05_pluck_detail
run all

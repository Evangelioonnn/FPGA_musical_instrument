set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir capacity32.gprj]
set_option -top_module capacity32_top
set_option -output_base_name capacity32
run all

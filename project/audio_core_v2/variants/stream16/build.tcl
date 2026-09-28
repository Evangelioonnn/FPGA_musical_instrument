set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir stream16.gprj]
set_option -top_module stream16_top
set_option -output_base_name stream16
run all

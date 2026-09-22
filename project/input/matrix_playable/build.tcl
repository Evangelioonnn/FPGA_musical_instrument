set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir matrix_playable.gprj]
set_option -top_module matrix_playable_top
set_option -output_base_name matrix_playable
run all

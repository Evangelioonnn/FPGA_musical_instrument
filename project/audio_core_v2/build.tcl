set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir audio_v2.gprj]
set_option -top_module audio_v2_top
set_option -output_base_name audio_v2
run all

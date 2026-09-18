set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir audio_format.gprj]
set_option -top_module audio_format_top
set_option -output_base_name audio_format
run all

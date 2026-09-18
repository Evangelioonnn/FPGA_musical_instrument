set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir audio_quality.gprj]
set_option -top_module audio_quality_top
set_option -output_base_name audio_quality
run all

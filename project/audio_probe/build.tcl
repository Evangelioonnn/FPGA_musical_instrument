set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir audio_probe.gprj]
set_option -top_module audio_probe_top
set_option -output_base_name audio_probe
run all

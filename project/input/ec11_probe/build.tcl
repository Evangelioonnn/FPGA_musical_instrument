set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir ec11_probe.gprj]
set_option -top_module ec11_audio_probe_top
set_option -output_base_name ec11_probe
run all

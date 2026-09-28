set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir audio_fx_lab.gprj]
set_option -top_module fx_resource_top
set_option -output_base_name audio_fx_lab
run all

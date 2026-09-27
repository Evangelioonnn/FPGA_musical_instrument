set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir five_02_spectral.gprj]
set_option -top_module five_02_spectral
set_option -output_base_name five_02_spectral
run all

set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir custom_harmonic.gprj]
set_option -top_module custom_harmonic_top
set_option -output_base_name custom_harmonic
run all

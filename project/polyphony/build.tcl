set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir polyphony.gprj]
set_option -top_module polyphony_top
set_option -output_base_name polyphony
run all

set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir knob_timbre.gprj]
set_option -top_module knob_timbre_top
set_option -output_base_name knob_timbre
run all

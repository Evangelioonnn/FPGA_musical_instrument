set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir fm_probe.gprj]
set_option -top_module fm_probe_top
set_option -output_base_name fm_probe
run all

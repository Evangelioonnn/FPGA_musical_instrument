set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir pluck_probe.gprj]
set_option -top_module pluck_probe_top
set_option -output_base_name pluck_probe
run all

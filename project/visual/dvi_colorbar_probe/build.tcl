set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir dvi_colorbar_probe.gprj]
set_option -top_module top_mod
set_option -output_base_name dvi_colorbar_probe
run all

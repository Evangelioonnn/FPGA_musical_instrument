set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir instrument.gprj]
set_option -top_module instrument_top
set_option -output_base_name instrument
run all

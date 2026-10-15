set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir instrument_ui_redesign.gprj]
set_option -top_module instrument_ui_top
set_option -output_base_name instrument_ui_redesign
run all

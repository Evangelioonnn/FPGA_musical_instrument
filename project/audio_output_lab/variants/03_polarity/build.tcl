set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir 03_polarity.gprj]
set_option -top_module output_03_polarity
set_option -output_base_name 03_polarity
run all

set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir 04_clean_reed.gprj]
set_option -top_module palette_04_clean_reed
set_option -output_base_name 04_clean_reed
run all

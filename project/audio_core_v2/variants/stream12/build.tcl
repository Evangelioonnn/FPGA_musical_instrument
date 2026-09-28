set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir stream12.gprj]
set_option -top_module stream12_top
set_option -output_base_name stream12
run all

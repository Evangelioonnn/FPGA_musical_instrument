set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir five_01_balance.gprj]
set_option -top_module five_01_balance
set_option -output_base_name five_01_balance
run all

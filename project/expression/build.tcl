set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir expression.gprj]
set_option -top_module expression_top
set_option -output_base_name expression
run all

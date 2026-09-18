set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir expression_baseline.gprj]
set_option -top_module expression_baseline_top
set_option -output_base_name expression_baseline
run all

set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir looper_refinement_lab.gprj]
set_option -top_module looper_refinement_top
set_option -output_base_name looper_refinement_lab
run all

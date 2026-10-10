set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir looper_convergence_lab.gprj]
set_option -top_module looper_convergence_top
set_option -output_base_name looper_convergence_lab
set_option -clock_route_order 1
run all

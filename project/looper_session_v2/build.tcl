set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir looper_session_v2.gprj]
set_option -top_module looper_session_top
set_option -output_base_name looper_session_v2
run all

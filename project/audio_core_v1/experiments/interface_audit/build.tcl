set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir interface_audit.gprj]
set_option -top_module audio_core
set_option -output_base_name interface_audit
run syn

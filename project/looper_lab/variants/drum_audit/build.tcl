set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir drum_audit.gprj]
set_option -top_module drum_audit_top
set_option -output_base_name drum_audit
run all

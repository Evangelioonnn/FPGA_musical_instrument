set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir session_audit.gprj]
set_option -top_module session_audit_top
set_option -output_base_name session_audit
run all

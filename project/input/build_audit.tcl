set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir input_audit.gprj]
set_option -top_module input_audit_top
set_option -output_base_name input_audit
run syn

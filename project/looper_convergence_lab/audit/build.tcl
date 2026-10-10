set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir refinement_audit.gprj]
set_option -top_module refinement_audit_top
set_option -output_base_name refinement_audit
run all

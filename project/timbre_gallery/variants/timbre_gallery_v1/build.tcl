set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir timbre_gallery_v1.gprj]
set_option -top_module timbre_gallery_v1
set_option -output_base_name timbre_gallery_v1
run all

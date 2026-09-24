set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir resource_timbre.gprj]
if {![info exists ::env(RESOURCE_TIMBRE_VARIANT)]} { set variant harmonic } else { set variant $::env(RESOURCE_TIMBRE_VARIANT) }
if {$variant eq "harmonic"} { set top resource_harmonic8_top } elseif {$variant eq "pluck"} { set top resource_pluck8_top } else { error "Unknown variant" }
set_option -top_module $top
set_option -output_base_name resource_${variant}8
run all

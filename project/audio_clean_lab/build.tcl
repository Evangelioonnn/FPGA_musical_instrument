set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir audio_clean_lab.gprj]

if {![info exists ::env(AUDIO_CLEAN_VARIANT)]} {
    set variant reference_x8
} else {
    set variant $::env(AUDIO_CLEAN_VARIANT)
}

switch -- $variant {
    reference_x8 { set top audio_clean_top_reference_x8 }
    harmonic_piano { set top audio_clean_top_harmonic_piano }
    low_fm { set top audio_clean_top_low_fm }
    triangle { set top audio_clean_top_triangle }
    default { error "Unknown AUDIO_CLEAN_VARIANT: $variant" }
}

set_option -top_module $top
set_option -output_base_name audio_clean_$variant
run all

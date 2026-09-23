set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir audio_noise_lab.gprj]

if {![info exists ::env(AUDIO_NOISE_VARIANT)]} {
    set variant baseline
} else {
    set variant $::env(AUDIO_NOISE_VARIANT)
}

switch -- $variant {
    baseline { set top noise_lab_top_baseline }
    activity_gate { set top noise_lab_top_activity_gate }
    gain_x2 { set top noise_lab_top_gain_x2 }
    gain_x4 { set top noise_lab_top_gain_x4 }
    oversample_x2 { set top noise_lab_top_oversample_x2 }
    oversample_x4 { set top noise_lab_top_oversample_x4 }
    default { error "Unknown AUDIO_NOISE_VARIANT: $variant" }
}

set_option -top_module $top
set_option -output_base_name audio_noise_$variant
run all

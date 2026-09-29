# Source this file from an existing Gowin project. No pins/clocks are imported.
namespace eval audio_import {
    variable tool_dir [file dirname [file normalize [info script]]]
    variable repo_root [file normalize [file join $tool_dir .. .. ..]]
}
source [file join $audio_import::tool_dir source_manifest.tcl]

proc audio_import::files {{profile core} {bank_override ""}} {
    variable profiles
    variable repo_root
    variable default_bank
    if {![info exists profiles($profile)]} {error "Unknown audio source profile: $profile"}
    set result {}
    set replacements 0
    foreach relative $profiles($profile) {
        if {$bank_override ne "" && $relative eq $default_bank} {
            set relative $bank_override
            incr replacements
        }
        if {[file pathtype $relative] ne "relative"} {
            error "Package paths must be repository-relative: $relative"
        }
        set path [file normalize [file join $repo_root $relative]]
        set prefix [string tolower "${repo_root}/"]
        if {[string first $prefix [string tolower $path]] != 0 || ![file isfile $path]} {
            error "Source is missing or outside repository: $relative"
        }
        if {[file extension $path] ne ".v"} {error "Only Verilog sources are imported"}
        if {[lsearch -exact $result $path] >= 0} {error "Duplicate source: $relative"}
        lappend result $path
    }
    if {$bank_override ne "" && $replacements != 1} {
        error "Bank override must replace exactly one core-bank entry"
    }
    return $result
}

proc audio_import::apply {{profile core} {top ""} {bank_override ""}} {
    variable profile_top
    if {$top eq ""} {set top $profile_top($profile)}
    foreach path [files $profile $bank_override] {add_file -type verilog $path}
    set_option -top_module $top
    return $top
}

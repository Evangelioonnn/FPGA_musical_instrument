# Five-timbre performance core

This A-owned candidate collects the five user-selected presets in one playable
firmware, with two sound-balancing comparisons. See [SPEC](SPEC.md) for stable
IDs and control semantics, [BOARD_TEST](BOARD_TEST.md) for physical audition,
and [VALIDATION](VALIDATION.md) for the actual completed gates.

Generate projects with `python project/five_timbre_core/tools/generate.py`.
Run RTL checks with `python project/five_timbre_core/sim/run_five.py`.
Build one variant with
`python project/five_timbre_core/tools/build.py --variant five_00_reference`
(likewise `five_01_balance` or `five_02_spectral`). Source
hashes, resources, timing violations and `.fs` hash are recorded under each
variant's ignored `impl/build_provenance.json`. The three variant projects
share only source and controls; each has its own bitstream.

The `sim/render_results.json` and `sim/audio/` outputs come from actual RTL
rendering with `python project/five_timbre_core/tools/render_five.py` after
`run_five.py` compiles the work library. Four retained presets are compared
with previously archived gallery PCM hashes. The original pluck is compared
frame by frame with the older `final_bank` in a separate testbench.

This candidate has not been listened to on the board or integrated with C's
display and Bluetooth. The independent gallery and original dual-timbre
firmwares remain useful rollback points.
